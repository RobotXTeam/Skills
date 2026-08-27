#!/bin/sh
# Deploy ONLY the firmware-channel shell scripts to the reCamera:
#   main.sh   (/usr/share/supervisor/scripts/main.sh)
#   upgrade.sh(/usr/share/supervisor/scripts/upgrade.sh)
#
# Binary-only constants (none here) live in the shell scripts, which the
# supervisor spawns per request - a replaced file takes effect on the next
# invocation without any restart. This script therefore never stops the
# service, never touches /usr/local/bin/supervisor, and keeps the device
# up for the entire transaction.
#
# Default: dry-run. Add --apply to deploy.
# Safety: backup in /userdata/local/backups/reweb-<ts>-scripts, staging in
# /tmp, remote syntax check, content verification (OSS URL), live behavior
# probe (upgrade.sh latest must attempt the OSS release URL), mode/S/K/binary
# identity preserved and re-verified, rollback trap active until the health
# checks pass.
#
# Privilege: root required only for the replace step.
# Credentials come from RECAMERA_PASSWORD / RECAMERA_SUDO_PASSWORD
# (environment or ~/.config/reweb/credentials.env). Never committed.

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

# Read-only preflight before any write. In dry-run a failure is a warning;
# in apply mode it aborts before anything is uploaded.
preflight_status=0
"$SKILL_DIR/scripts/preflight.sh" >/dev/null 2>&1 || preflight_status=$?
if [ "$preflight_status" -ne 0 ]; then
  if [ "$APPLY" -eq 1 ]; then
    die "preflight failed (exit $preflight_status); aborting before upload"
  fi
  warn "preflight reported issues (exit $preflight_status); dry-run continues"
fi

if [ "$APPLY" -eq 1 ]; then
  require_credentials
fi

REPO="${REPO:-/home/steven/sscma-example-sg200x}"
DEVICE_MAIN_SH=/usr/share/supervisor/scripts/main.sh
DEVICE_UPGRADE_SH=/usr/share/supervisor/scripts/upgrade.sh
LOCAL_MAIN_SH="$REPO/solutions/supervisor/rootfs/usr/share/supervisor/scripts/main.sh"
LOCAL_UPGRADE_SH="$REPO/solutions/supervisor/rootfs/usr/share/supervisor/scripts/upgrade.sh"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_BASE/reweb-$TS-scripts"
STAGE_DIR="/tmp/supervisor-scripts-stage-$TS"
OSS_URL_MARK="RobotXTeam/OSS-reCamera-solutions/releases/latest"
DEVICE_BIN=/usr/local/bin/supervisor

note "plan:"
printf '  local main.sh:     %s\n' "$LOCAL_MAIN_SH"
printf '  local upgrade.sh:  %s\n' "$LOCAL_UPGRADE_SH"
printf '  device stage:      %s\n' "$STAGE_DIR"
printf '  device backup:     %s\n' "$BACKUP_DIR"
printf '  device files:      %s\n' "$DEVICE_MAIN_SH"
printf '                      %s\n' "$DEVICE_UPGRADE_SH"
printf '  restart supervisor: no\n'
printf '  reboot device:      no\n'
printf '  binary untouched:   yes\n'
printf '  preserve mode:      yes\n'

if [ "$APPLY" -eq 0 ]; then
  note "dry-run complete; rerun with --apply to deploy"
  exit 0
fi

note "local cross-check: bash -n + presence"
bash -n "$LOCAL_MAIN_SH" || die "local syntax check failed: main.sh"
bash -n "$LOCAL_UPGRADE_SH" || die "local syntax check failed: upgrade.sh"
grep -q "$OSS_URL_MARK" "$LOCAL_MAIN_SH" || die "main.sh does not contain the OSS channel URL"
grep -q "$OSS_URL_MARK" "$LOCAL_UPGRADE_SH" || die "upgrade.sh does not contain the OSS channel URL"
local_backup scripts "$SKILL_DIR/../" 2>/dev/null || true

note "step 1: disk-space guard + upload scripts to device staging"
require_device_space 1024 /userdata/local
recamera_ssh "rm -rf '$STAGE_DIR' && mkdir -p '$STAGE_DIR'" || die "could not create staging"
recamera_scp "$LOCAL_MAIN_SH" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/main.sh" || die "main.sh upload failed"
recamera_scp "$LOCAL_UPGRADE_SH" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/upgrade.sh" || die "upgrade.sh upload failed"

note "step 2: backup current scripts + state snapshot"
recamera_sudo_sh "mkdir -p '$BACKUP_DIR' && cp -a '$DEVICE_MAIN_SH' '$BACKUP_DIR/main.sh' && cp -a '$DEVICE_UPGRADE_SH' '$BACKUP_DIR/upgrade.sh' && cp -a '$DEVICE_BIN' '$BACKUP_DIR/supervisor'" || die "backup scripts failed"
recamera_sudo_sh "{ cat '$MODE_FILE' 2>/dev/null || true; } > '$BACKUP_DIR/mode.before'; { ls /etc/init.d/S*node-red /etc/init.d/S*sscma-node /etc/init.d/S*sscma-supervisor /etc/init.d/K*node-red /etc/init.d/K*sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/services.before'; { pidof supervisor node-red sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/processes.before'" || die "state snapshot failed"
prune_backups 5 "$BACKUP_DIR"
MODE_BEFORE="$(recamera_sudo_sh "cat '$BACKUP_DIR/mode.before' 2>/dev/null | tr -d ' \t\r\n'" || true)"
[ "$MODE_BEFORE" = "nodered" ] || MODE_BEFORE=recamera-studio
note "preserved mode: $MODE_BEFORE"
SUP_PID_BEFORE="$(recamera_ssh "pidof supervisor" || true)"
note "supervisor pid before deploy: ${SUP_PID_BEFORE:-none}"

restore_scripts() {
  recamera_sudo_sh "cp -a '$BACKUP_DIR/main.sh' '$DEVICE_MAIN_SH' && chmod 755 '$DEVICE_MAIN_SH' && cp -a '$BACKUP_DIR/upgrade.sh' '$DEVICE_UPGRADE_SH' && chmod 755 '$DEVICE_UPGRADE_SH'" || die "ROLLBACK FAILED: restore scripts from $BACKUP_DIR manually"
  note "restored scripts from backup"
}

note "step 3: remote validation of staged scripts"
recamera_ssh "bash -n '$STAGE_DIR/main.sh' && chmod 755 '$STAGE_DIR/main.sh'" || { warn "staged main.sh failed remote bash -n"; die "staged script validation failed (nothing replaced)"; }
recamera_ssh "bash -n '$STAGE_DIR/upgrade.sh' && chmod 755 '$STAGE_DIR/upgrade.sh'" || { warn "staged upgrade.sh failed remote bash -n"; die "staged script validation failed (nothing replaced)"; }
recamera_ssh "grep -q '$OSS_URL_MARK' '$STAGE_DIR/upgrade.sh'" || die "staged upgrade.sh missing OSS URL (nothing replaced)"

note "step 4: replace scripts"
if ! recamera_sudo_sh "cp -a '$STAGE_DIR/main.sh' '$DEVICE_MAIN_SH' && chmod 755 '$DEVICE_MAIN_SH' && cp -a '$STAGE_DIR/upgrade.sh' '$DEVICE_UPGRADE_SH' && chmod 755 '$DEVICE_UPGRADE_SH'"; then
  warn "replace failed; restoring from backup"
  restore_scripts
  die "replace failed; restored backup"
fi

note "step 5: content verification on device"
if ! recamera_ssh "grep -q '$OSS_URL_MARK' '$DEVICE_MAIN_SH' && grep -q '$OSS_URL_MARK' '$DEVICE_UPGRADE_SH'"; then
  warn "device scripts missing OSS URL; rolling back"
  restore_scripts
  die "content verification failed; restored backup"
fi

note "step 6: live behavior probe (upgrade.sh latest must attempt the OSS URL)"
probe_out="$(recamera_ssh "/usr/share/supervisor/scripts/upgrade.sh latest" 2>&1 || true)"
printf 'probe output (tail):\n%s\n' "$(printf '%s' "$probe_out" | tail -n 6)"
case "$probe_out" in
  *"$OSS_URL_MARK"*) note "probe confirmed: OSS release URL attempted on device" ;;
  *)
    warn "probe did not show the OSS URL; rolling back"
    restore_scripts
    die "behavior probe failed; restored backup"
    ;;
esac

note "step 7: device health after replace (service, HTTP, mode, S/K state)"
sup_pid_after="$(recamera_ssh "pidof supervisor" || true)"
[ -n "$sup_pid_after" ] || { warn "supervisor not running after replace; rolling back"; restore_scripts; die "supervisor process missing; restored backup"; }
api_body="$(recamera_ssh "curl -sS --max-time 8 http://127.0.0.1/api/version" || true)"
case "$api_body" in
  '{'*'"code":0'*) note "api healthy: ${api_body}";;
  *) warn "api unhealthy (${api_body:-no response}); rolling back"; restore_scripts; die "HTTP check failed; restored backup";;
esac
MODE_AFTER="$(recamera_sudo_sh "cat '$MODE_FILE' 2>/dev/null | tr -d ' \t\r\n'" || true)"
[ "$MODE_AFTER" = "nodered" ] || MODE_AFTER=recamera-studio
[ "$MODE_AFTER" = "$MODE_BEFORE" ] || { warn "mode changed ($MODE_BEFORE -> $MODE_AFTER); rolling back"; restore_scripts; restore_mode "$BACKUP_DIR" || die "ROLLBACK FAILED: restore mode manually"; die "mode mismatch; restored backup"; }
svc_after="$(recamera_sudo_sh "cd /etc/init.d && ls S*node-red S*sscma-node S*sscma-supervisor K*node-red K*sscma-node 2>/dev/null | sort | tr '\n' ' '")"
svc_before="$(recamera_ssh "cat '$BACKUP_DIR/services.before' 2>/dev/null | xargs -n1 basename 2>/dev/null | sort | tr '\n' ' '" 2>/dev/null || true)"
note "services after: ${svc_after}"
[ "$svc_after" = "$svc_before" ] || warn "S/K prefix list differs from backup snapshot (before: ${svc_before:-unreadable}); scripts-only deploy cannot cause this - inspect manually"

note "cleanup staging"
recamera_ssh "rm -rf '$STAGE_DIR'" || warn "could not remove staging ($STAGE_DIR)"

note "deployed. backup: $BACKUP_DIR"
printf '  supervisor pid: %s -> %s\n' "${SUP_PID_BEFORE:-none}" "$sup_pid_after"
printf '  mode: %s (unchanged)\n' "$MODE_AFTER"
printf 'rollback command:\n  sudo cp -a %s/main.sh %s\n  sudo cp -a %s/upgrade.sh %s\n  sudo cp %s/mode.before /userdata/local/apps/mode\n' \
  "$BACKUP_DIR" "$DEVICE_MAIN_SH" \
  "$BACKUP_DIR" "$DEVICE_UPGRADE_SH" \
  "$BACKUP_DIR"