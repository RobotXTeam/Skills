#!/bin/sh
# Stop the tunnel process recorded by start-tunnels.sh.
# Only kills the PID this skill stored; leaves unrelated forwards alone.

set -u

SKILL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SKILL_DIR/scripts/lib.sh"

if [ ! -f "$PID_FILE" ]; then
  note "no tunnel PID recorded; nothing to stop"
  exit 0
fi

pid="$(cat "$PID_FILE" 2>/dev/null || true)"
[ -n "$pid" ] || { note "empty PID file; removing"; rm -f "$PID_FILE"; exit 0; }

if ! kill -0 "$pid" 2>/dev/null; then
  note "recorded tunnel process $pid is not running"
  rm -f "$PID_FILE"
  exit 0
fi

cmdline="$(ps -o args= -p "$pid" 2>/dev/null || true)"
case "$cmdline" in
  *ssh*-N*"$RECAMERA_HOST"*) ;;
  *)
    warn "recorded PID $pid does not look like a tunnel to $RECAMERA_HOST; not killing"
    rm -f "$PID_FILE"
    exit 1
    ;;
esac

kill "$pid" 2>/dev/null || true
for _ in 1 2 3 4 5; do
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.2
done
if kill -0 "$pid" 2>/dev/null; then
  warn "process did not exit; sending KILL"
  kill -KILL "$pid" 2>/dev/null || true
fi
rm -f "$PID_FILE"
note "tunnels stopped"
