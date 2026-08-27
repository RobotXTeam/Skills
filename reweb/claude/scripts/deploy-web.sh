#!/bin/sh
# Deploy the Supervisor web UI to the reCamera.
#
# Default: dry-run. Add --apply to write to the device.
#
# Steps when applied:
#   1. local: npm run build
#   2. upload dist to /tmp/supervisor-www-staging-<ts>/
#   3. remote backup /usr/share/supervisor/www -> /userdata/local/backups/...
#   4. validate staged index.html/assets on device
#   5. atomic-ish swap: old web root removed, staging moved into place
#   6. restore from backup if any step fails
#
# No device reboot or Supervisor restart for a web-only deploy.
#
# Privilege: writes under /usr/share/supervisor/www require root on the device.
# Set RECAMERA_PASSWORD / RECAMERA_SUDO_PASSWORD in the environment (or in
# ~/.config/reweb/credentials.env) before --apply; the script fails with a
# clear message when neither source is configured. Never commit passwords to
# the repository or echo them in logs.

set -eu
# pipefail is not POSIX and dash omits it; probe in a subshell first because
# dash treats a bare `set -o pipefail` failure as a fatal special-builtin error.
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

SKILL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SKILL_DIR/scripts/lib.sh"
latch_transport

APPLY=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

# Read-only preflight before any build or upload. Runs in dry-run too so a
# planned deploy surfaces environment problems early; in dry-run a preflight
# failure is a warning, in apply mode it aborts before anything is built.
preflight_status=0
"$SKILL_DIR/scripts/preflight.sh" || preflight_status=$?
if [ "$preflight_status" -ne 0 ]; then
  if [ "$APPLY" -eq 1 ]; then
    die "preflight failed (exit $preflight_status); aborting before build"
  fi
  warn "preflight reported issues (exit $preflight_status); dry-run continues"
fi

if [ "$APPLY" -eq 1 ]; then
  require_credentials
fi

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_BASE/reweb-$TS-web"
STAGE_DIR="/tmp/supervisor-www-staging-$TS"
WEB_ROOT=/usr/share/supervisor/www
DIST_DIR="$WWW_DIR/dist"

note "step 1: local npm run build"
if [ "$APPLY" -eq 0 ]; then
  note "(dry-run: would run npm --prefix $WWW_DIR run build)"
elif [ "$APPLY" -eq 1 ]; then
  ( cd "$WWW_DIR" && npm run build ) || die "frontend build failed"
  local_backup web "$DIST_DIR" "$TS"
fi
[ -f "$DIST_DIR/index.html" ] || note "NOTE: $DIST_DIR/index.html not found (dry-run or build not run)"

note "plan:"
printf '  local dist:        %s\n' "$DIST_DIR"
printf '  device stage:     %s\n' "$STAGE_DIR"
printf '  device backup:    %s\n' "$BACKUP_DIR"
printf '  device web root:  %s\n' "$WEB_ROOT"
printf '  restart supervisor: no\n'
printf '  reboot device:      no\n'

if [ "$APPLY" -eq 0 ]; then
  note "dry-run complete; rerun with --apply to deploy"
  exit 0
fi

[ -f "$DIST_DIR/index.html" ] || die "refusing to deploy: $DIST_DIR/index.html missing"

# Confirm the hashed assets the built index.html references actually exist
# locally before we upload anything.
refs="$(sed -n 's/.*\(src\|href\)="\([^"]*\.\(js\|css\)\)".*/\2/p' "$DIST_DIR/index.html" 2>/dev/null | sort -u || true)"
[ -n "$refs" ] || die "refusing to deploy: $DIST_DIR/index.html references no hashed assets"
asset_missing=0
for asset in $refs; do
  if [ ! -f "$DIST_DIR$asset" ]; then
    warn "built index.html references missing asset: $DIST_DIR$asset"
    asset_missing=1
  fi
done
[ "$asset_missing" -eq 0 ] || die "refusing to deploy: built index.html references missing assets"

note "step 2: upload dist to device staging"
# Device disk-space guard before writing anything.
need_kb="$(du -sk "$DIST_DIR" 2>/dev/null | awk '{print $1}' || true)"
case "$need_kb" in
  ''|*[!0-9]*) need_kb=16384 ;;
esac
need_kb=$((need_kb * 2 + 16384))
require_device_space "$need_kb" /userdata/local

recamera_ssh "rm -rf '$STAGE_DIR' && mkdir -p '$STAGE_DIR'" || die "could not create staging on device"
# scp -r rejects the "dir/." source syntax under its SFTP transport; stream
# a tar through the existing SSH pipe instead (works over the two-hop proxy).
tar -C "$DIST_DIR" -cf - . | recamera_ssh "tar -xf - -C '$STAGE_DIR'" || die "upload failed"

note "step 3: backup current web root"
recamera_sudo_sh "mkdir -p '$BACKUP_DIR' && cp -a '$WEB_ROOT' '$BACKUP_DIR/www'" || die "backup failed"
recamera_sudo_sh "{ cat '$MODE_FILE' 2>/dev/null || true; } > '$BACKUP_DIR/mode.before'; { ls /etc/init.d/S*node-red /etc/init.d/S*sscma-node /etc/init.d/S*sscma-supervisor /etc/init.d/K*node-red /etc/init.d/K*sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/services.before'; { pidof supervisor node-red sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/processes.before'" || die "state snapshot failed"
prune_backups 5 "$BACKUP_DIR"

note "step 4: validate staged assets"
validation="$(recamera_sudo_sh "test -f '$STAGE_DIR/index.html' && echo ok || echo missing" || true)"
[ "$validation" = "ok" ] || {
  warn "staging validation failed: $validation"
  recamera_sudo_sh "rm -rf '$STAGE_DIR'" || true
  die "aborted before replacing web root"
}

note "step 5: swap web root"
swap_cmd="rm -rf '$WEB_ROOT.failed' && mv '$WEB_ROOT' '$WEB_ROOT.failed' && mv '$STAGE_DIR' '$WEB_ROOT' && rm -rf '$WEB_ROOT.failed'"
recamera_sudo_sh "$swap_cmd" || {
  warn "swap failed; restoring backup"
  recamera_sudo_sh "rm -rf '$WEB_ROOT' && cp -a '$BACKUP_DIR/www' '$WEB_ROOT' && rm -rf '$STAGE_DIR'" || die "ROLLBACK FAILED: restore $WEB_ROOT from $BACKUP_DIR/www manually"
  restore_mode "$BACKUP_DIR" || die "ROLLBACK FAILED: restore /userdata/local/apps/mode from $BACKUP_DIR/mode.before manually"
  die "swap failed; restored from backup"
}

note "step 6: verify served UI, hashed assets and API JSON"
# The served index must reference hashed JS/CSS that actually return 200, and
# /api/version must answer with JSON (not just any 200 page). This catches a
# stale cached index, missing asset chunks, and a non-Supervisor page.
web_health_ok() {
  http_code="$(recamera_ssh "curl -sS --max-time 8 -o /tmp/recamera-live-index -w '%{http_code}' http://127.0.0.1/" || true)"
  [ "$http_code" = "200" ] || return 1
  idx="$(recamera_ssh "cat /tmp/recamera-live-index" || true)"
  case "$idx" in
    *'src="'*'.js'*|*'href="'*'.css'*) ;;
    *) return 1 ;;
  esac
  refs="$(printf '%s' "$idx" | grep -oE '(src|href)="[^"]+\.(js|css)"' | sed -E 's/^[^=]*="//; s/"$//' | sort -u || true)"
  [ -n "$refs" ] || return 1
  for asset in $refs; do
    asset_code="$(recamera_ssh "curl -sS --max-time 8 -o /dev/null -w '%{http_code}' \"http://127.0.0.1$asset\"" || true)"
    [ "$asset_code" = "200" ] || return 1
  done
  api_body="$(recamera_ssh "curl -sS --max-time 8 http://127.0.0.1/api/version" || true)"
  case "$api_body" in
    '{'*'"code"'*) return 0 ;;
    *) return 1 ;;
  esac
}

health_ok=0
attempt=0
while [ "$attempt" -lt 5 ]; do
  health_ok=1
  web_health_ok || health_ok=0
  if [ "$health_ok" -eq 1 ]; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [ "$health_ok" -ne 1 ]; then
  warn "health check failed; restoring backup"
  recamera_sudo_sh "rm -rf '$WEB_ROOT' && cp -a '$BACKUP_DIR/www' '$WEB_ROOT'" || die "ROLLBACK FAILED: restore $WEB_ROOT from $BACKUP_DIR/www manually"
  restore_mode "$BACKUP_DIR" || die "ROLLBACK FAILED: restore /userdata/local/apps/mode from $BACKUP_DIR/mode.before manually"
  die "health check failed; restored web backup"
fi

note "deployed. backup: $BACKUP_DIR"
note "health: index + hashed assets + /api/version JSON verified"
printf 'rollback command:\n  sudo rm -rf %s && sudo cp -a %s/www %s\n  sudo cp %s/mode.before /userdata/local/apps/mode\n' "$WEB_ROOT" "$BACKUP_DIR" "$WEB_ROOT" "$BACKUP_DIR"
