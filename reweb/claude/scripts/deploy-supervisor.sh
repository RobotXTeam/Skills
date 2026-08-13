#!/bin/sh
# Deploy the Supervisor backend to the reCamera.
#
# Default: dry-run. Add --apply to write to the device.
# Add --include-runtime to also deploy main.sh and S93sscma-supervisor.
#
# Steps when applied:
#   1. local: cross-build supervisor (and package unless DEB path is supplied)
#   2. upload binary/package to /tmp/supervisor-stage-<ts>/
#   3. remote backup binary, main.sh, init script, mode, services
#   4. stop Supervisor only (Node-RED/sscma-node left untouched)
#   5. replace binary (and runtime files if requested)
#   6. start Supervisor; verify process, HTTP and persisted mode
#   7. restore from backup and stop on failure
#
# Privilege: root required. Set RECAMERA_SUDO_PASSWORD in the environment
# if sudo needs a password. Never commit passwords.

set -u

SKILL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SKILL_DIR/scripts/lib.sh"

APPLY=0
INCLUDE_RUNTIME=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    --include-runtime) INCLUDE_RUNTIME=1 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

REPO="${REPO:-/home/steven/sscma-example-sg200x}"
BUILD_DIR="$REPO/solutions/supervisor/build-live"
BIN_NAME=supervisor
DEVICE_BIN=/usr/local/bin/supervisor
DEVICE_MAIN_SH=/usr/share/supervisor/scripts/main.sh
DEVICE_INIT=/etc/init.d/S93sscma-supervisor
MODE_FILE=/userdata/local/apps/mode
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/userdata/local/backups/reweb-$TS"
STAGE_DIR="/tmp/supervisor-stage-$TS"

note "step 1: cross-build"
[ "$APPLY" -eq 0 ] && note "(dry-run: would cross-build under $BUILD_DIR)"
if [ "$APPLY" -eq 1 ]; then
  [ -n "${SG200X_SDK_PATH:-}" ] || die "SG200X_SDK_PATH is not set"
  export PATH="/home/steven/host-tools/gcc/riscv64-linux-musl-x86_64/bin:$PATH"
  ( cd "$REPO" && cmake -S solutions/supervisor -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DWEB=OFF ) || die "cmake configure failed"
  ( cd "$REPO" && cmake --build "$BUILD_DIR" -j"$(nproc)" ) || die "cmake build failed"
fi

LOCAL_BIN="$BUILD_DIR/$BIN_NAME"
[ -f "$LOCAL_BIN" ] || note "NOTE: $LOCAL_BIN not found (dry-run or build not run)"

note "plan:"
printf '  local binary:     %s\n' "$LOCAL_BIN"
printf '  device stage:     %s\n' "$STAGE_DIR"
printf '  device backup:    %s\n' "$BACKUP_DIR"
printf '  device binary:    %s\n' "$DEVICE_BIN"
printf '  include runtime:  %s\n' "$([ "$INCLUDE_RUNTIME" -eq 1 ] && echo yes || echo no)"
printf '  restart supervisor: yes\n'
printf '  reboot device:      no\n'
printf '  preserve mode:      yes\n'

if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  printf '  runtime files:     main.sh S93sscma-supervisor\n'
fi

if [ "$APPLY" -eq 0 ]; then
  note "dry-run complete; rerun with --apply to deploy"
  [ "$INCLUDE_RUNTIME" -eq 1 ] && note "runtime deploy requires extra verification; review safety-and-rollback.md"
  exit 0
fi

[ -f "$LOCAL_BIN" ] || die "refusing to deploy: $LOCAL_BIN missing"

note "step 2: upload binary to device staging"
recamera_ssh "rm -rf '$STAGE_DIR' && mkdir -p '$STAGE_DIR'" || die "could not create staging"
recamera_scp "$LOCAL_BIN" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/$BIN_NAME" || die "upload failed"

if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  LOCAL_MAIN_SH="$REPO/solutions/supervisor/rootfs/usr/share/supervisor/scripts/main.sh"
  LOCAL_INIT="$REPO/solutions/supervisor/rootfs/etc/init.d/S93sscma-supervisor"
  recamera_scp "$LOCAL_MAIN_SH" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/main.sh" || die "runtime script upload failed"
  recamera_scp "$LOCAL_INIT" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/S93sscma-supervisor" || die "init script upload failed"
fi

note "step 3: backup current backend"
recamera_sudo_sh "mkdir -p '$BACKUP_DIR' && cp -a '$DEVICE_BIN' '$BACKUP_DIR/supervisor'" || die "backup binary failed"
if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  recamera_sudo_sh "cp -a '$DEVICE_MAIN_SH' '$BACKUP_DIR/main.sh'" || die "backup main.sh failed"
  recamera_sudo_sh "cp -a '$DEVICE_INIT' '$BACKUP_DIR/S93sscma-supervisor'" || die "backup init failed"
fi
recamera_sudo_sh "{ cat '$MODE_FILE' 2>/dev/null || true; } > '$BACKUP_DIR/mode.before'; { ls /etc/init.d/S*node-red /etc/init.d/S*sscma-node /etc/init.d/S*sscma-supervisor /etc/init.d/K*node-red /etc/init.d/K*sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/services.before'; { pidof supervisor node-red sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/processes.before'" || die "state snapshot failed"
MODE_BEFORE="$(recamera_ssh "cat '$BACKUP_DIR/mode.before' 2>/dev/null | tr -d ' \t\r\n'" || true)"
[ "$MODE_BEFORE" = "nodered" ] || MODE_BEFORE=console
note "preserved mode: $MODE_BEFORE"

note "step 4: stop Supervisor"
recamera_sudo "/etc/init.d/S93sscma-supervisor stop" || warn "supervisor stop returned non-zero"

note "step 5: replace binary"
recamera_sudo_sh "cp -a '$STAGE_DIR/$BIN_NAME' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || {
  warn "replace failed; restoring binary"
  recamera_sudo_sh "cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED: restore $DEVICE_BIN from $BACKUP_DIR/supervisor manually"
  recamera_sudo "/etc/init.d/S93sscma-supervisor start" || true
  die "replace failed; restored binary"
}
if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  if ! recamera_sudo_sh "cp -a '$STAGE_DIR/main.sh' '$DEVICE_MAIN_SH' && chmod 755 '$DEVICE_MAIN_SH' && cp -a '$STAGE_DIR/S93sscma-supervisor' '$DEVICE_INIT' && chmod 755 '$DEVICE_INIT'"; then
    warn "runtime replace failed; rolling back all backend files"
    recamera_sudo_sh "cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN' && cp -a '$BACKUP_DIR/main.sh' '$DEVICE_MAIN_SH' && chmod 755 '$DEVICE_MAIN_SH' && cp -a '$BACKUP_DIR/S93sscma-supervisor' '$DEVICE_INIT' && chmod 755 '$DEVICE_INIT'" || die "ROLLBACK FAILED: restore files from $BACKUP_DIR manually"
    recamera_sudo "/etc/init.d/S93sscma-supervisor start" || true
    die "runtime replace failed; restored backup"
  fi
fi

note "step 6: start Supervisor and verify"
recamera_sudo "/etc/init.d/S93sscma-supervisor start" || {
  warn "start failed; rolling back"
  recamera_sudo_sh "cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED: restore binary manually"
  [ "$INCLUDE_RUNTIME" -eq 1 ] && recamera_sudo_sh "cp -a '$BACKUP_DIR/main.sh' '$DEVICE_MAIN_SH'; cp -a '$BACKUP_DIR/S93sscma-supervisor' '$DEVICE_INIT'" || true
  recamera_sudo "/etc/init.d/S93sscma-supervisor start" || die "ROLLBACK FAILED: supervisor did not start from backup"
  die "start failed; restored backup"
}

note "verifying process, HTTP and mode"
sleep 2
procs="$(recamera_ssh "pidof $BIN_NAME 2>/dev/null || true")"
[ -n "$procs" ] || {
  warn "no supervisor process after start; rolling back"
  recamera_sudo "/etc/init.d/S93sscma-supervisor stop" || true
  recamera_sudo_sh "cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED"
  recamera_sudo "/etc/init.d/S93sscma-supervisor start" || die "ROLLBACK FAILED"
  die "no process; restored backup"
}

MODE_AFTER="$(recamera_ssh "cat '$MODE_FILE' 2>/dev/null | tr -d ' \t\r\n'" || true)"
[ "$MODE_AFTER" = "nodered" ] || MODE_AFTER=console
if [ "$MODE_AFTER" != "$MODE_BEFORE" ]; then
  warn "mode changed: before=$MODE_BEFORE after=$MODE_AFTER"
  warn "rolling back to preserve mode"
  recamera_sudo "/etc/init.d/S93sscma-supervisor stop" || true
  recamera_sudo_sh "cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED"
  [ "$INCLUDE_RUNTIME" -eq 1 ] && recamera_sudo_sh "cp -a '$BACKUP_DIR/main.sh' '$DEVICE_MAIN_SH'; cp -a '$BACKUP_DIR/S93sscma-supervisor' '$DEVICE_INIT'" || true
  recamera_sudo "/etc/init.d/S93sscma-supervisor start" || die "ROLLBACK FAILED"
  die "mode mismatch; restored backup"
fi

http_code="$(recamera_ssh "curl -sS --max-time 8 -o /tmp/recamera-live-api -w '%{http_code}' http://127.0.0.1/api/version" || true)"
if [ "$http_code" != "200" ]; then
  warn "Supervisor HTTP health check failed ($http_code); rolling back"
  recamera_sudo "/etc/init.d/S93sscma-supervisor stop" || true
  recamera_sudo_sh "cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED"
  [ "$INCLUDE_RUNTIME" -eq 1 ] && recamera_sudo_sh "cp -a '$BACKUP_DIR/main.sh' '$DEVICE_MAIN_SH'; cp -a '$BACKUP_DIR/S93sscma-supervisor' '$DEVICE_INIT'" || true
  recamera_sudo "/etc/init.d/S93sscma-supervisor start" || die "ROLLBACK FAILED"
  die "HTTP check failed; restored backup"
fi

note "deployed. backup: $BACKUP_DIR"
note "health: pid=$procs api=$http_code mode=$MODE_AFTER"
printf 'rollback command:\n  sudo /etc/init.d/S93sscma-supervisor stop\n  sudo cp -a %s/supervisor %s\n  [sudo cp -a %s/main.sh %s; sudo cp -a %s/S93sscma-supervisor %s]\n  sudo /etc/init.d/S93sscma-supervisor start\n' \
  "$BACKUP_DIR" "$DEVICE_BIN" \
  "$BACKUP_DIR" "$DEVICE_MAIN_SH" "$BACKUP_DIR" "$DEVICE_INIT"
