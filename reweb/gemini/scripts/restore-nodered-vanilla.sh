#!/bin/sh
# One-time de-injection: restore the reCamera Node-RED installation to its
# byte-for-byte factory state ("100% 原厂").
#
# What this reverts (all injected by the retired inject-studio-return.sh):
#   1. /home/recamera/.node-red/settings.js          -> baseline (injection block + legacy
#                                                        page.scripts line removed)
#   2. node_modules/node-red-contrib-sscma/nodes/camera.js        -> npm 0.3.6 original
#      (undoes pause->enabled remap; original uses "pause" per D1)
#   3. node_modules/node-red-contrib-seeed-recamera/nodes/light.js -> npm 0.0.9 original
#      (undoes httpAdminRoot-aware path build; original hardcodes /camera/<state>)
#   4. node_modules/@flowfuse/node-red-dashboard/dist/index.html  -> npm 1.26.0 original
#      + restores the package's own favicon files (favicon.ico, apple-touch-icon.png,
#        favicon.svg) which the injector had overwritten with Studio assets;
#        the injected favicon.svg shim (svg referencing /logo_favicon.png) is replaced
#        by the package's real favicon.svg
#   5. /usr/share/supervisor/nodered/  (retired injection asset dir) -> removed
#   6. /usr/share/supervisor/www/sscma/ (jmuxer mirror for the /editor root) -> removed
#
# Deliberately NOT touched:
#   - ~/.node-red/flows.json          (user data; already stock Workspace flow)
#   - ~/.node-red/.config.runtime.json perms 0600 (security fix, invisible; D2)
#   - /usr/lib/node_modules/node-red/custom.css (already identical to factory)
#   - /userdata/local/apps/mode, S/K prefixes, any service other than S03 restart
#     needed to reread settings.js
#
# Safety: read-only preflight, timestamped backup of every touched file under
# /userdata/local/backups/reweb-<ts>-nodered-vanilla, /tmp staging, sha256
# verification, S03 restart only, mode preserved, rollback trap.
#
# Default: dry-run. Add --apply to execute.

set -eu
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

SKILL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SKILL_DIR/scripts/lib.sh"

APPLY=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

PAYLOAD="${NODE_RED_VANILLA_PAYLOAD:-$REPO/.reweb-backups/nodered-vanilla-payload.tar.gz}"
[ -s "$PAYLOAD" ] || die "payload missing: $PAYLOAD (build it with build-vanilla-payload.sh)"

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_BASE/reweb-$TS-nodered-vanilla"
STAGE_DIR="/tmp/nodered-vanilla-$TS"
USER_DIR=/home/recamera/.node-red
NODERED_ASSET_DIR=/usr/share/supervisor/nodered
WWW_SSCMA_DIR=/usr/share/supervisor/www/sscma
SET="$USER_DIR/settings.js"
CAM="$USER_DIR/node_modules/node-red-contrib-sscma/nodes/camera.js"
LIGHT="$USER_DIR/node_modules/node-red-contrib-seeed-recamera/nodes/light.js"
DASH="$USER_DIR/node_modules/@flowfuse/node-red-dashboard/dist"

note "plan:"
printf '  payload:        %s\n' "$PAYLOAD"
printf '  staging:        %s\n' "$STAGE_DIR"
printf '  backup:         %s\n' "$BACKUP_DIR"
printf '  restore files:  settings.js, camera.js, light.js, dashboard index+favicons\n'
printf '  remove dirs:    %s\n' "$NODERED_ASSET_DIR"
printf '                  %s\n' "$WWW_SSCMA_DIR"
printf '  service restart: S03node-red only (to reread settings.js)\n'
printf '  mode/S91 untouched: yes\n'

if [ "$APPLY" -eq 0 ]; then
  note "dry-run complete; rerun with --apply to restore stock Node-RED"
  exit 0
fi

require_credentials
"$SKILL_DIR/scripts/preflight.sh" >/dev/null || die "preflight failed; aborting"

note "step 1: stage payload on device and verify checksums"
require_device_space 2048 /userdata/local
recamera_ssh "rm -rf '$STAGE_DIR' && mkdir -p '$STAGE_DIR'" || die "staging failed"
recamera_scp "$PAYLOAD" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/payload.tar.gz" || die "payload upload failed"
recamera_ssh "tar -xzf '$STAGE_DIR/payload.tar.gz' -C '$STAGE_DIR' && cd '$STAGE_DIR' && sha256sum -c SHA256SUMS" || die "payload checksum verification failed"

MODE_BEFORE="$(recamera_sudo_sh "cat '$MODE_FILE' 2>/dev/null | tr -d ' \t\r\n'" || true)"
MODE_BEFORE="${MODE_BEFORE:-recamera-studio}"
note "current mode: $MODE_BEFORE (must be preserved)"

note "step 2: backup everything we are about to change"
recamera_sudo_sh "mkdir -p '$BACKUP_DIR' \
  && cp -a '$SET' '$BACKUP_DIR/settings.js.before' \
  && cp -a '$CAM' '$BACKUP_DIR/camera.js.before' \
  && cp -a '$LIGHT' '$BACKUP_DIR/light.js.before' \
  && cp -a '$DASH/index.html' '$BACKUP_DIR/dashboard-index.html.before' \
  && { cp -a '$DASH/favicon.ico' '$BACKUP_DIR/favicon.ico.before' 2>/dev/null || true; } \
  && { cp -a '$DASH/apple-touch-icon.png' '$BACKUP_DIR/apple-touch-icon.png.before' 2>/dev/null || true; } \
  && { cp -a '$DASH/favicon.svg' '$BACKUP_DIR/favicon.svg.before' 2>/dev/null || true; } \
  && { [ -d '$NODERED_ASSET_DIR' ] && cp -a '$NODERED_ASSET_DIR' '$BACKUP_DIR/nodered-assets.before' || true; } \
  && { [ -d '$WWW_SSCMA_DIR' ] && cp -a '$WWW_SSCMA_DIR' '$BACKUP_DIR/www-sscma.before' || true; } \
  && { cat '$MODE_FILE' 2>/dev/null || true; } > '$BACKUP_DIR/mode.before' \
  && { ls /etc/init.d/S*node-red /etc/init.d/K*node-red /etc/init.d/S*sscma-node /etc/init.d/K*sscma-node /etc/init.d/*sscma-supervisor 2>/dev/null || true; } > '$BACKUP_DIR/services.before'" || die "backup failed"

rollback() {
  warn "rolling back from $BACKUP_DIR"
  recamera_sudo_sh "cp -a '$BACKUP_DIR/settings.js.before' '$SET' \
    && cp -a '$BACKUP_DIR/camera.js.before' '$CAM' \
    && cp -a '$BACKUP_DIR/light.js.before' '$LIGHT' \
    && cp -a '$BACKUP_DIR/dashboard-index.html.before' '$DASH/index.html' \
    && { [ -f '$BACKUP_DIR/favicon.ico.before' ] && cp -a '$BACKUP_DIR/favicon.ico.before' '$DASH/favicon.ico' || rm -f '$DASH/favicon.ico'; } \
    && { [ -f '$BACKUP_DIR/apple-touch-icon.png.before' ] && cp -a '$BACKUP_DIR/apple-touch-icon.png.before' '$DASH/apple-touch-icon.png' || rm -f '$DASH/apple-touch-icon.png'; } \
    && { [ -f '$BACKUP_DIR/favicon.svg.before' ] && cp -a '$BACKUP_DIR/favicon.svg.before' '$DASH/favicon.svg' || rm -f '$DASH/favicon.svg'; } \
    && { [ -d '$BACKUP_DIR/nodered-assets.before' ] && cp -a '$BACKUP_DIR/nodered-assets.before' '$NODERED_ASSET_DIR' || true; } \
    && { [ -d '$BACKUP_DIR/www-sscma.before' ] && cp -a '$BACKUP_DIR/www-sscma.before' '$WWW_SSCMA_DIR' || true; } \
    && chown -R recamera:recamera '$USER_DIR' '$NODERED_ASSET_DIR' 2>/dev/null || true \
    && cp -a '$BACKUP_DIR/mode.before' '$MODE_FILE' \
    && { [ -x /etc/init.d/S03node-red ] && /etc/init.d/S03node-red restart || true; }" || die "ROLLBACK FAILED: restore from $BACKUP_DIR manually"
}

note "step 3: replace files (studio mode = node-red parked, no stop needed first)"
if ! recamera_sudo_sh "cp '$STAGE_DIR/settings.js' '$SET' \
  && cp '$STAGE_DIR/camera.js' '$CAM' \
  && cp '$STAGE_DIR/light.js' '$LIGHT' \
  && cp '$STAGE_DIR/dashboard-index.html' '$DASH/index.html' \
  && cp '$STAGE_DIR/favicon.ico' '$DASH/favicon.ico' \
  && cp '$STAGE_DIR/apple-touch-icon.png' '$DASH/apple-touch-icon.png' \
  && cp '$STAGE_DIR/favicon.svg' '$DASH/favicon.svg' \
  && chown recamera:recamera '$SET' '$CAM' '$LIGHT' '$DASH/index.html' '$DASH/favicon.ico' '$DASH/apple-touch-icon.png' '$DASH/favicon.svg' \
  && chmod 644 '$SET' \
  && rm -rf '$NODERED_ASSET_DIR' '$WWW_SSCMA_DIR'"; then
  rollback
  die "replacement failed; restored backup"
fi

note "step 4: verify factory state on device"
# grep -q returns 0 when the pattern IS present; use exit codes, never parse counts.
fail_check=""
if recamera_ssh "grep -q 'reCamera Studio Node-RED integration' '$SET'"; then
  fail_check=" settings.js still contains the injection block"
fi
if recamera_ssh "grep -q 'studio-return' '$DASH/index.html'"; then
  fail_check="$fail_check dashboard html still patched"
fi
if recamera_ssh "grep -q 'RED.settings.httpAdminRoot' '$LIGHT'"; then
  fail_check="$fail_check light.js still patched"
fi
if ! recamera_ssh "grep -q '\"pause\", true' '$CAM'"; then
  fail_check="$fail_check camera.js missing stock pause calls"
fi
recamera_ssh "cd '$STAGE_DIR' && sha256sum -c SHA256SUMS" >/dev/null 2>&1 || fail_check="$fail_check staged payload checksum mismatch"
recamera_ssh "node -e 'require(\"$SET\")'" >/dev/null 2>&1 || fail_check="$fail_check settings.js failed node syntax check"
if [ -n "$fail_check" ]; then
  warn "verification failed:$fail_check"
  rollback
  die "verification failed; restored backup"
fi
note "factory verification passed"

MODE_AFTER="$(recamera_sudo_sh "cat '$MODE_FILE' 2>/dev/null | tr -d ' \t\r\n'" || true)"
[ "$MODE_AFTER" = "$MODE_BEFORE" ] || { rollback; die "mode changed ($MODE_BEFORE -> $MODE_AFTER); restored backup"; }

note "step 5: restart Node-RED to reread settings.js (only if armed/running)"
recamera_sudo_sh "if [ -x /etc/init.d/S03node-red ]; then /etc/init.d/S03node-red restart; fi" || warn "S03 restart skipped/failed (parked or already stopped)"

recamera_ssh "rm -rf '$STAGE_DIR'" || warn "could not clean staging"

note "restored stock Node-RED. backup: $BACKUP_DIR"
note "verify boundary: curl http://<device>:1880/ (editor), :1880/editor (404), :1880/dashboard (FlowFuse)"
printf 'rollback command:\n  ssh device: sudo sh -c "cp -a %s/settings.js.before %s && cp -a %s/camera.js.before %s && cp -a %s/light.js.before %s && cp -a %s/dashboard-index.html.before %s/index.html && [ -x /etc/init.d/S03node-red ] && /etc/init.d/S03node-red restart"\n' \
  "$BACKUP_DIR" "$SET" "$BACKUP_DIR" "$CAM" "$BACKUP_DIR" "$LIGHT" "$BACKUP_DIR" "$DASH"
