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
# Set RECAMERA_SUDO_PASSWORD in the environment if sudo needs a password.
# Never commit passwords to the repository or echo them in logs.

set -u

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

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/userdata/local/backups/reweb-$TS"
STAGE_DIR="/tmp/supervisor-www-staging-$TS"
WEB_ROOT=/usr/share/supervisor/www
DIST_DIR="$WWW_DIR/dist"

note "step 1: local npm run build"
[ "$APPLY" -eq 0 ] && note "(dry-run: would run npm --prefix $WWW_DIR run build)"
if [ "$APPLY" -eq 1 ]; then
  ( cd "$WWW_DIR" && npm run build ) || die "frontend build failed"
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

note "step 2: upload dist to device staging"
recamera_ssh "rm -rf '$STAGE_DIR' && mkdir -p '$STAGE_DIR'" || die "could not create staging on device"
# scp -r rejects the "dir/." source syntax under its SFTP transport; stream
# a tar through the existing SSH pipe instead (works over the two-hop proxy).
tar -C "$DIST_DIR" -cf - . | recamera_ssh "tar -xf - -C '$STAGE_DIR'" || die "upload failed"

note "step 3: backup current web root"
recamera_sudo_sh "mkdir -p '$BACKUP_DIR' && cp -a '$WEB_ROOT' '$BACKUP_DIR/www'" || die "backup failed"
recamera_sudo_sh "{ cat /userdata/local/apps/mode 2>/dev/null || true; } > '$BACKUP_DIR/mode.before'; { ls /etc/init.d/S*node-red /etc/init.d/S*sscma-node /etc/init.d/S*sscma-supervisor /etc/init.d/K*node-red /etc/init.d/K*sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/services.before'; { pidof supervisor node-red sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/processes.before'" || die "state snapshot failed"

note "step 4: validate staged assets"
validation="$(recamera_sudo_sh "test -f '$STAGE_DIR/index.html' && echo ok || echo missing")"
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
  die "swap failed; restored from backup"
}

note "step 6: verify served UI and Supervisor API"
http_code="$(recamera_ssh "curl -sS --max-time 8 -o /tmp/recamera-live-index -w '%{http_code}' http://127.0.0.1/; test -s /tmp/recamera-live-index || true" || true)"
api_code="$(recamera_ssh "curl -sS --max-time 8 -o /tmp/recamera-live-api -w '%{http_code}' http://127.0.0.1/api/version" || true)"
if [ "$http_code" != "200" ] || [ "$api_code" != "200" ]; then
  warn "health check failed (ui=$http_code api=$api_code); restoring backup"
  recamera_sudo_sh "rm -rf '$WEB_ROOT' && cp -a '$BACKUP_DIR/www' '$WEB_ROOT'" || die "ROLLBACK FAILED: restore $WEB_ROOT from $BACKUP_DIR/www manually"
  die "health check failed; restored web backup"
fi

note "deployed. backup: $BACKUP_DIR"
note "health: ui=$http_code api=$api_code"
printf 'rollback command:\n  sudo rm -rf %s && sudo cp -a %s/www %s\n' "$WEB_ROOT" "$BACKUP_DIR" "$WEB_ROOT"
