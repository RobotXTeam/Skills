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
# Privilege: root required. Set RECAMERA_PASSWORD / RECAMERA_SUDO_PASSWORD in
# the environment (or in ~/.config/reweb/credentials.env) before --apply; the
# script fails with a clear message when neither source is configured.
# Never commit passwords.

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
INCLUDE_RUNTIME=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    --include-runtime) INCLUDE_RUNTIME=1 ;;
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

REPO="${REPO:-/home/steven/sscma-example-sg200x}"
BUILD_DIR="$REPO/solutions/supervisor/build-live"
BIN_NAME=supervisor
DEVICE_BIN=/usr/local/bin/supervisor
DEVICE_MAIN_SH=/usr/share/supervisor/scripts/main.sh
DEVICE_TRIGGER_SH=/usr/share/supervisor/scripts/trigger.sh
DEVICE_INIT=/etc/init.d/S93sscma-supervisor
DEVICE_NODERED_DIR=/usr/share/supervisor/nodered
DEVICE_NODE_RED_CSS=/usr/lib/node_modules/node-red/custom.css
LOCAL_MAIN_SH="$REPO/solutions/supervisor/rootfs/usr/share/supervisor/scripts/main.sh"
LOCAL_TRIGGER_SH="$REPO/solutions/supervisor/rootfs/usr/share/supervisor/scripts/trigger.sh"
LOCAL_INIT="$REPO/solutions/supervisor/rootfs/etc/init.d/S93sscma-supervisor"
LOCAL_NODERED_DIR="$REPO/solutions/supervisor/rootfs/usr/share/supervisor/nodered"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_BASE/reweb-$TS-supervisor"
STAGE_DIR="/tmp/supervisor-stage-$TS"

note "step 1: cross-build"
if [ "$APPLY" -eq 0 ]; then
  note "(dry-run: would cross-build under $BUILD_DIR)"
else
  [ -n "${SG200X_SDK_PATH:-}" ] || die "SG200X_SDK_PATH is not set"
  export PATH="/home/steven/host-tools/gcc/riscv64-linux-musl-x86_64/bin:$PATH"
  ( cd "$REPO" && cmake -S solutions/supervisor -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DWEB=OFF ) || die "cmake configure failed"
  ( cd "$REPO" && cmake --build "$BUILD_DIR" -j"$(nproc)" ) || die "cmake build failed"
  local_backup supervisor "$BUILD_DIR/$BIN_NAME" "$TS"
fi

LOCAL_BIN="$BUILD_DIR/$BIN_NAME"
[ -f "$LOCAL_BIN" ] || note "NOTE: $LOCAL_BIN not found (dry-run or build not run)"

rt_yesno=no
if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  rt_yesno=yes
fi

note "plan:"
printf '  local binary:     %s\n' "$LOCAL_BIN"
printf '  device stage:     %s\n' "$STAGE_DIR"
printf '  device backup:    %s\n' "$BACKUP_DIR"
printf '  device binary:    %s\n' "$DEVICE_BIN"
printf '  include runtime:  %s\n' "$rt_yesno"
printf '  restart supervisor: yes\n'
printf '  reboot device:      no\n'
printf '  preserve mode:      yes\n'

if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  printf '  runtime files:     main.sh trigger.sh S93sscma-supervisor nodered/\n'
fi

if [ "$APPLY" -eq 0 ]; then
  note "dry-run complete; rerun with --apply to deploy"
  [ "$INCLUDE_RUNTIME" -eq 1 ] && note "runtime deploy requires extra verification; review safety-and-rollback.md"
  exit 0
fi

[ -f "$LOCAL_BIN" ] || die "refusing to deploy: $LOCAL_BIN missing"

note "step 2: upload binary to device staging"
# Device disk-space guard before writing anything.
need_kb=16384
bin_kb="$(du -sk "$LOCAL_BIN" 2>/dev/null | awk '{print $1}' || true)"
case "$bin_kb" in
  ''|*[!0-9]*) bin_kb=2048 ;;
esac
need_kb=$((need_kb + bin_kb * 2))
if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  rt_kb="$(du -sk "$LOCAL_MAIN_SH" "$LOCAL_TRIGGER_SH" "$LOCAL_INIT" "$LOCAL_NODERED_DIR" 2>/dev/null | awk '{s+=$1} END{print s}' || true)"
  case "$rt_kb" in
    ''|*[!0-9]*) rt_kb=512 ;;
  esac
  need_kb=$((need_kb + rt_kb * 2))
fi
require_device_space "$need_kb" /userdata/local

recamera_ssh "rm -rf '$STAGE_DIR' && mkdir -p '$STAGE_DIR'" || die "could not create staging"
recamera_scp "$LOCAL_BIN" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/$BIN_NAME" || die "upload failed"

if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  recamera_scp "$LOCAL_MAIN_SH" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/main.sh" || die "runtime script upload failed"
  recamera_scp "$LOCAL_TRIGGER_SH" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/trigger.sh" || die "trigger script upload failed"
  recamera_scp "$LOCAL_INIT" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/S93sscma-supervisor" || die "init script upload failed"
  # Node-RED injection assets: preserve whatever the device already has, then
  # overlay the repo versions of the files this repo ships.
  recamera_ssh "mkdir -p '$STAGE_DIR/nodered' && { cp -a '$DEVICE_NODERED_DIR'/. '$STAGE_DIR/nodered'/ 2>/dev/null || true; }" || die "nodered staging failed"
  for nr_file in custom.css studio-return.css studio-return.js inject-studio-return.sh enable-nodered-log.sh; do
    [ -f "$LOCAL_NODERED_DIR/$nr_file" ] || continue
    recamera_scp "$LOCAL_NODERED_DIR/$nr_file" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/nodered/$nr_file" || die "nodered asset upload failed: $nr_file"
  done
fi

note "step 3: backup current backend"
recamera_sudo_sh "mkdir -p '$BACKUP_DIR' && cp -a '$DEVICE_BIN' '$BACKUP_DIR/supervisor'" || die "backup binary failed"
if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  recamera_sudo_sh "cp -a '$DEVICE_MAIN_SH' '$BACKUP_DIR/main.sh'" || die "backup main.sh failed"
  # trigger.sh may not exist on older firmware — back it up only if present.
  recamera_sudo_sh "[ -f '$DEVICE_TRIGGER_SH' ] && cp -a '$DEVICE_TRIGGER_SH' '$BACKUP_DIR/trigger.sh' || true" || die "backup trigger.sh failed"
  recamera_sudo_sh "cp -a '$DEVICE_INIT' '$BACKUP_DIR/S93sscma-supervisor'" || die "backup init failed"
  # nodered injection assets and the factory CSS endpoint they maintain.
  recamera_sudo_sh "[ -d '$DEVICE_NODERED_DIR' ] && cp -a '$DEVICE_NODERED_DIR' '$BACKUP_DIR/nodered' || mkdir -p '$BACKUP_DIR/nodered'; [ -f '$DEVICE_NODE_RED_CSS' ] && cp -a '$DEVICE_NODE_RED_CSS' '$BACKUP_DIR/node-red-custom.css' || true" || die "backup nodered assets failed"
fi
recamera_sudo_sh "{ cat '$MODE_FILE' 2>/dev/null || true; } > '$BACKUP_DIR/mode.before'; { ls /userdata/local/apps/.force_studio /userdata/local/apps/.force_console 2>/dev/null || true; } > '$BACKUP_DIR/force_flags.before'; { ls /etc/init.d/S*node-red /etc/init.d/S*sscma-node /etc/init.d/S*sscma-supervisor /etc/init.d/K*node-red /etc/init.d/K*sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/services.before'; { pidof supervisor node-red sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/processes.before'" || die "state snapshot failed"
prune_backups 5 "$BACKUP_DIR"
MODE_BEFORE="$(recamera_sudo_sh "cat '$BACKUP_DIR/mode.before' 2>/dev/null | tr -d ' \t\r\n'" || true)"
[ "$MODE_BEFORE" = "nodered" ] || MODE_BEFORE=recamera-studio
note "preserved mode: $MODE_BEFORE"

restore_runtime_backup() {
  [ "$INCLUDE_RUNTIME" -eq 1 ] || return 0
  recamera_sudo_sh "cp -a '$BACKUP_DIR/main.sh' '$DEVICE_MAIN_SH' && chmod 755 '$DEVICE_MAIN_SH'; { [ -f '$BACKUP_DIR/trigger.sh' ] && cp -a '$BACKUP_DIR/trigger.sh' '$DEVICE_TRIGGER_SH' && chmod 755 '$DEVICE_TRIGGER_SH' || rm -f '$DEVICE_TRIGGER_SH'; }; cp -a '$BACKUP_DIR/S93sscma-supervisor' '$DEVICE_INIT' && chmod 755 '$DEVICE_INIT'; rm -rf '$DEVICE_NODERED_DIR' && cp -a '$BACKUP_DIR/nodered' '$DEVICE_NODERED_DIR'; { [ -f '$BACKUP_DIR/node-red-custom.css' ] && cp -a '$BACKUP_DIR/node-red-custom.css' '$DEVICE_NODE_RED_CSS' || true; }"
}

cleanup_staging() {
  recamera_sudo_sh "rm -rf '$STAGE_DIR'" || true
}

note "step 4: stop Supervisor"
recamera_sudo "/etc/init.d/S93sscma-supervisor stop" || warn "supervisor stop returned non-zero"

note "step 5: replace binary"
recamera_sudo_sh "cp -a '$STAGE_DIR/$BIN_NAME' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || {
  warn "replace failed; restoring binary"
  recamera_sudo_sh "rm -rf '$STAGE_DIR'; cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED: restore $DEVICE_BIN from $BACKUP_DIR/supervisor manually"
  restore_mode "$BACKUP_DIR" || die "ROLLBACK FAILED: restore /userdata/local/apps/mode from $BACKUP_DIR/mode.before manually"
  recamera_sudo "/etc/init.d/S93sscma-supervisor start" || true
  die "replace failed; restored binary"
}
if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  if ! recamera_sudo_sh "cp -a '$STAGE_DIR/main.sh' '$DEVICE_MAIN_SH' && chmod 755 '$DEVICE_MAIN_SH' && cp -a '$STAGE_DIR/trigger.sh' '$DEVICE_TRIGGER_SH' && chmod 755 '$DEVICE_TRIGGER_SH' && cp -a '$STAGE_DIR/S93sscma-supervisor' '$DEVICE_INIT' && chmod 755 '$DEVICE_INIT' && rm -rf '$DEVICE_NODERED_DIR' && cp -a '$STAGE_DIR/nodered' '$DEVICE_NODERED_DIR' && chmod 755 '$DEVICE_NODERED_DIR/inject-studio-return.sh' '$DEVICE_NODERED_DIR/enable-nodered-log.sh' && chmod 644 '$DEVICE_NODERED_DIR/custom.css' '$DEVICE_NODERED_DIR/studio-return.css' '$DEVICE_NODERED_DIR/studio-return.js'"; then
    warn "runtime replace failed; rolling back all backend files"
    recamera_sudo_sh "rm -rf '$STAGE_DIR'; cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED: restore binary from $BACKUP_DIR manually"
    restore_runtime_backup || die "ROLLBACK FAILED: restore runtime files from $BACKUP_DIR manually"
    restore_mode "$BACKUP_DIR" || die "ROLLBACK FAILED: restore /userdata/local/apps/mode from $BACKUP_DIR/mode.before manually"
    recamera_sudo "/etc/init.d/S93sscma-supervisor start" || true
    die "runtime replace failed; restored backup"
  fi
fi

note "step 6: start Supervisor and verify"
recamera_sudo "/etc/init.d/S93sscma-supervisor start" || {
  warn "start failed; rolling back"
  recamera_sudo_sh "rm -rf '$STAGE_DIR'; cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED: restore binary manually"
  restore_runtime_backup || die "ROLLBACK FAILED: restore runtime files manually"
  restore_mode "$BACKUP_DIR" || die "ROLLBACK FAILED: restore /userdata/local/apps/mode from $BACKUP_DIR/mode.before manually"
  recamera_sudo "/etc/init.d/S93sscma-supervisor start" || die "ROLLBACK FAILED: supervisor did not start from backup"
  die "start failed; restored backup"
}

note "verifying process, HTTP and mode"
# Detection runs as root: on this device /proc/<pid>/exe of a root-owned
# process is unreadable by the unprivileged recamera user, which used to
# read as "no supervisor process" and trigger a false rollback.
procs=""
attempt=0
while [ "$attempt" -lt 20 ]; do
  procs="$(recamera_sudo_sh "for p in \$(pidof $BIN_NAME 2>/dev/null); do exe=\$(readlink /proc/\$p/exe 2>/dev/null); [ \"\$exe\" = '$DEVICE_BIN' ] && printf '%s ' \"\$p\"; done" || true)"
  if [ -n "$procs" ]; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
[ -n "$procs" ] || {
  warn "no supervisor process after start; rolling back"
  recamera_sudo "/etc/init.d/S93sscma-supervisor stop" || true
  recamera_sudo_sh "rm -rf '$STAGE_DIR'; cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED"
  restore_runtime_backup || die "ROLLBACK FAILED: restore runtime files manually"
  restore_mode "$BACKUP_DIR" || die "ROLLBACK FAILED: restore /userdata/local/apps/mode from $BACKUP_DIR/mode.before manually"
  recamera_sudo "/etc/init.d/S93sscma-supervisor start" || die "ROLLBACK FAILED"
  die "no process; restored backup"
}

MODE_AFTER="$(recamera_sudo_sh "cat '$MODE_FILE' 2>/dev/null | tr -d ' \t\r\n'" || true)"
[ "$MODE_AFTER" = "nodered" ] || MODE_AFTER=recamera-studio
if [ "$MODE_AFTER" != "$MODE_BEFORE" ]; then
  # Distinguish a legitimate reconcile_run_mode() rewrite from abnormal drift.
  # The init script (S93sscma-supervisor) legitimately rewrites mode when the
  # previous value was invalid/missing (one-time migration to recamera-studio)
  # or when a one-shot force flag (.force_studio / .force_console) was present
  # before this deploy. In those cases we accept the change and keep the new
  # binary; anything else rolls back to preserve mode.
  legitimate=0
  case "$MODE_BEFORE" in
    nodered | recamera-studio) ;;
    *) legitimate=1 ;;
  esac
  force_flags=""
  if [ "$legitimate" -eq 0 ]; then
    force_flags="$(recamera_sudo_sh "cat '$BACKUP_DIR/force_flags.before' 2>/dev/null | tr -d ' \t\r\n'" || true)"
    if [ -n "$force_flags" ]; then
      legitimate=1
    fi
  fi
  if [ "$legitimate" -eq 1 ]; then
    warn "mode changed during deploy ($MODE_BEFORE -> $MODE_AFTER); accepted as a legitimate init-script rewrite (invalid previous mode or a force flag was present)"
  else
    warn "mode changed unexpectedly: before=$MODE_BEFORE after=$MODE_AFTER"
    warn "rolling back to preserve mode"
    recamera_sudo "/etc/init.d/S93sscma-supervisor stop" || true
    recamera_sudo_sh "rm -rf '$STAGE_DIR'; cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED"
    restore_runtime_backup || die "ROLLBACK FAILED: restore runtime files manually"
    restore_mode "$BACKUP_DIR" || die "ROLLBACK FAILED: restore mode manually"
    recamera_sudo "/etc/init.d/S93sscma-supervisor start" || die "ROLLBACK FAILED"
    die "mode mismatch; restored backup"
  fi
fi

note "verifying HTTP /api/version (polling)"
api_ok=0
api_body=""
attempt=0
while [ "$attempt" -lt 20 ]; do
  api_body="$(recamera_ssh "curl -sS --max-time 8 http://127.0.0.1/api/version" || true)"
  case "$api_body" in
    '{'*'"code":0'*) api_ok=1 ;;
  esac
  if [ "$api_ok" -eq 1 ]; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [ "$api_ok" -ne 1 ]; then
  warn "Supervisor HTTP health check failed (${api_body:-no response}); rolling back"
  recamera_sudo "/etc/init.d/S93sscma-supervisor stop" || true
  recamera_sudo_sh "rm -rf '$STAGE_DIR'; cp -a '$BACKUP_DIR/supervisor' '$DEVICE_BIN' && chmod 755 '$DEVICE_BIN'" || die "ROLLBACK FAILED"
  restore_runtime_backup || die "ROLLBACK FAILED: restore runtime files manually"
  restore_mode "$BACKUP_DIR" || die "ROLLBACK FAILED: restore mode manually"
  recamera_sudo "/etc/init.d/S93sscma-supervisor start" || die "ROLLBACK FAILED"
  die "HTTP check failed; restored backup"
fi

if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  # Enable persistent Node-RED console logging (factory init logs to the void).
  # Idempotent and never restarts Node-RED; a failure here is non-fatal.
  if [ -f "$DEVICE_NODERED_DIR/enable-nodered-log.sh" ]; then
    nr_log_result="$(recamera_sudo "$DEVICE_NODERED_DIR/enable-nodered-log.sh" 2>&1 || true)"
    note "node-red log patcher: ${nr_log_result:-no-output}"
  fi
fi

cleanup_staging

note "deployed. backup: $BACKUP_DIR"
note "health: pid=$procs api=200 mode=$MODE_AFTER"
printf 'rollback command:\n  sudo /etc/init.d/S93sscma-supervisor stop\n  sudo cp -a %s/supervisor %s\n' "$BACKUP_DIR" "$DEVICE_BIN"
if [ "$INCLUDE_RUNTIME" -eq 1 ]; then
  printf '  sudo cp -a %s/main.sh %s\n  [ -f %s/trigger.sh ] && sudo cp -a %s/trigger.sh %s\n  sudo cp -a %s/S93sscma-supervisor %s\n  sudo rm -rf %s && sudo cp -a %s/nodered %s\n  [ -f %s/node-red-custom.css ] && sudo cp -a %s/node-red-custom.css %s\n' \
    "$BACKUP_DIR" "$DEVICE_MAIN_SH" \
    "$BACKUP_DIR" "$BACKUP_DIR" "$DEVICE_TRIGGER_SH" \
    "$BACKUP_DIR" "$DEVICE_INIT" \
    "$DEVICE_NODERED_DIR" "$BACKUP_DIR" "$DEVICE_NODERED_DIR" \
    "$BACKUP_DIR" "$BACKUP_DIR" "$DEVICE_NODE_RED_CSS"
fi
printf '  sudo cp %s/mode.before /userdata/local/apps/mode\n  sudo /etc/init.d/S93sscma-supervisor start\n' "$BACKUP_DIR"
