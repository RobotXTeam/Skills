#!/bin/sh
# Deploy the complete original reCamera Node-RED user-directory baseline.
# Default: dry-run. --apply stages, verifies, backs up, then replaces the
# target user directory while preserving the current reCamera run mode.

set -eu
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

BASELINE_DIR="${NODE_RED_BASELINE_DIR:-$REPO/.reweb-backups/nodered-original-192.168.42.1-20260816}"
ARCHIVE="$BASELINE_DIR/nodered-baseline.tar.gz"
CSS="$BASELINE_DIR/custom.css"
SUMS="$BASELINE_DIR/SHA256SUMS"
TS="$(date +%Y%m%d-%H%M%S)"
STAGE_DIR="/tmp/nodered-baseline-$TS"
BACKUP_DIR="$BACKUP_BASE/reweb-$TS-nodered-baseline"
USER_DIR=/home/recamera/.node-red
NODE_CSS=/usr/lib/node_modules/node-red/custom.css
INJECTOR=/usr/share/supervisor/nodered/inject-studio-return.sh

[ -s "$ARCHIVE" ] || die "baseline archive missing: $ARCHIVE"
[ -s "$CSS" ] || die "baseline CSS missing: $CSS"
[ -s "$SUMS" ] || die "baseline checksums missing: $SUMS"
(
  cd "$BASELINE_DIR"
  sha256sum -c "$SUMS"
) || die "baseline checksum verification failed"
tar -tzf "$ARCHIVE" | grep -qx '.node-red/settings.js' || die "baseline missing settings.js"
tar -tzf "$ARCHIVE" | grep -q '^.node-red/node_modules/' || die "baseline missing node_modules"

note "plan:"
printf '  baseline archive: %s\n' "$ARCHIVE"
printf '  target user dir:  %s\n' "$USER_DIR"
printf '  device stage:     %s\n' "$STAGE_DIR"
printf '  device backup:    %s\n' "$BACKUP_DIR"
printf '  preserve mode:    yes\n'
printf '  reboot device:    no\n'

if [ "$APPLY" -eq 0 ]; then
  note "dry-run complete; rerun with --apply to install the original Node-RED baseline"
  exit 0
fi

require_credentials
"$SKILL_DIR/scripts/preflight.sh" || die "preflight failed; aborting before upload"

archive_kb="$(du -sk "$ARCHIVE" "$CSS" | awk '{s+=$1} END{print s}')"
need_kb=$((archive_kb * 3 + 32768))
require_device_space "$need_kb" /userdata/local

note "step 1: upload baseline to device staging"
recamera_ssh "rm -rf '$STAGE_DIR' && mkdir -p '$STAGE_DIR/unpack'" || die "could not create staging"
recamera_scp "$ARCHIVE" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/baseline.tar.gz" || die "archive upload failed"
recamera_scp "$CSS" "$RECAMERA_USER@$RECAMERA_HOST:$STAGE_DIR/custom.css" || die "CSS upload failed"
recamera_ssh "tar -xzf '$STAGE_DIR/baseline.tar.gz' -C '$STAGE_DIR/unpack' && test -f '$STAGE_DIR/unpack/.node-red/settings.js' && test -d '$STAGE_DIR/unpack/.node-red/node_modules' && test -s '$STAGE_DIR/custom.css'" || die "staged baseline validation failed"

note "step 2: snapshot current mode, services, and Node-RED directory"
recamera_sudo_sh "mkdir -p '$BACKUP_DIR' && { [ -d '$USER_DIR' ] && cp -a '$USER_DIR' '$BACKUP_DIR/node-red.before' || mkdir -p '$BACKUP_DIR/node-red.before'; } && { [ -f '$NODE_CSS' ] && cp -a '$NODE_CSS' '$BACKUP_DIR/custom.css.before' || true; } && { cat '$MODE_FILE' 2>/dev/null || true; } > '$BACKUP_DIR/mode.before' && { ls /etc/init.d/S*node-red /etc/init.d/K*node-red /etc/init.d/S*sscma-node /etc/init.d/K*sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/services.before' && { pidof supervisor node-red node-red-pi node sscma-node 2>/dev/null || true; } > '$BACKUP_DIR/processes.before'" || die "backup failed"
MODE_BEFORE="$(recamera_sudo_sh "cat '$BACKUP_DIR/mode.before' 2>/dev/null | tr -d ' \\t\\r\\n'" || true)"
[ "$MODE_BEFORE" = nodered ] || MODE_BEFORE=recamera-studio
note "preserved mode: $MODE_BEFORE"

restore() {
  note "restoring Node-RED baseline backup"
  recamera_sudo_sh "if [ '$MODE_BEFORE' = nodered ]; then /etc/init.d/S91sscma-node stop >/dev/null 2>&1 || true; /etc/init.d/S03node-red stop >/dev/null 2>&1 || true; fi; rm -rf '$USER_DIR' && cp -a '$BACKUP_DIR/node-red.before' '$USER_DIR' && { [ -f '$BACKUP_DIR/custom.css.before' ] && cp -a '$BACKUP_DIR/custom.css.before' '$NODE_CSS' || true; } && cp -a '$BACKUP_DIR/mode.before' '$MODE_FILE' && chown -R recamera:recamera '$USER_DIR' && chmod 644 '$USER_DIR/settings.js' && { [ '$MODE_BEFORE' = nodered ] && /etc/init.d/S03node-red start >/dev/null 2>&1 && /etc/init.d/S91sscma-node start >/dev/null 2>&1 || true; }" || true
}

note "step 3: install original Node-RED baseline"
if ! recamera_sudo_sh "if [ '$MODE_BEFORE' = nodered ]; then /etc/init.d/S91sscma-node stop >/dev/null 2>&1 || true; /etc/init.d/S03node-red stop >/dev/null 2>&1 || true; fi; rm -rf '$USER_DIR.next' && cp -a '$STAGE_DIR/unpack/.node-red' '$USER_DIR.next' && chown -R recamera:recamera '$USER_DIR.next' && chmod 644 '$USER_DIR.next/settings.js' && mv '$USER_DIR' '$USER_DIR.previous' && mv '$USER_DIR.next' '$USER_DIR' && rm -rf '$USER_DIR.previous' && cp -a '$STAGE_DIR/custom.css' '$NODE_CSS' && chmod 644 '$NODE_CSS' && { [ -x '$INJECTOR' ] && '$INJECTOR' '$USER_DIR/settings.js' || true; } && { [ '$MODE_BEFORE' = nodered ] && /etc/init.d/S03node-red start >/dev/null 2>&1 && /etc/init.d/S91sscma-node start >/dev/null 2>&1 || true; }"; then
  restore
  die "baseline install failed; restored backup"
fi

MODE_AFTER="$(recamera_sudo_sh "cat '$MODE_FILE' 2>/dev/null | tr -d ' \\t\\r\\n'" || true)"
[ "$MODE_AFTER" = nodered ] || MODE_AFTER=recamera-studio
if [ "$MODE_AFTER" != "$MODE_BEFORE" ]; then
  restore
  die "mode changed unexpectedly; restored backup"
fi

note "step 4: verify installed baseline"
verify="$(recamera_sudo_sh "node -e 'const s=require(\"$USER_DIR/settings.js\"); const p=require(\"$USER_DIR/package.json\"); if(s.editorTheme.page.title!==\"reCamera\" || !p.dependencies[\"@flowfuse/node-red-dashboard\"]) process.exit(1); console.log(\"ok\")' && test -d '$USER_DIR/node_modules/@flowfuse/node-red-dashboard' && test -f '$NODE_CSS' && stat -c '%U:%G' '$USER_DIR/settings.js'" || true)"
case "$verify" in
  *ok*recamera:recamera*) ;;
  *) restore; die "baseline verification failed; restored backup" ;;
esac

recamera_sudo_sh "rm -rf '$STAGE_DIR'" || true
note "deployed. backup: $BACKUP_DIR"
printf 'rollback command:\n  sudo /etc/init.d/S93sscma-supervisor stop\n  sudo rm -rf %s && sudo cp -a %s/node-red.before %s\n  sudo cp %s/mode.before %s\n  sudo /etc/init.d/S93sscma-supervisor start\n' "$USER_DIR" "$BACKUP_DIR" "$USER_DIR" "$BACKUP_DIR" "$MODE_FILE"
