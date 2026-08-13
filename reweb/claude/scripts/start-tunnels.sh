#!/bin/sh
# Start local forwards to the reCamera through OpenWrt.
# Safe to re-run; existing listeners are left alone.

set -u

SKILL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SKILL_DIR/scripts/lib.sh"

ensure_run_dir

# If a previous tunnel managed by this skill is still alive, keep it.
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
  note "tunnels already running (pid $(cat "$PID_FILE"))"
  exit 0
fi

listening=0
for port in "$TUNNEL_PORT_HTTP" "$TUNNEL_PORT_NODERED" "$TUNNEL_PORT_TTYD" "$TUNNEL_PORT_DEBUG"; do
  is_port_listening "$port" && listening=$((listening + 1))
done
if [ "$listening" -eq 4 ]; then
  note "all tunnel ports already listening (external tunnel); not starting"
  exit 0
fi
[ "$listening" -eq 0 ] || die "only $listening of 4 tunnel ports are available; resolve the partial port collision first"

note "starting tunnels: $OPENWRT_SSH_TARGET -> $RECAMERA_HOST"
ssh -N \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o StrictHostKeyChecking=accept-new \
  -L "$TUNNEL_PORT_HTTP:$RECAMERA_HOST:$DEVICE_PORT_HTTP" \
  -L "$TUNNEL_PORT_NODERED:$RECAMERA_HOST:$DEVICE_PORT_NODERED" \
  -L "$TUNNEL_PORT_TTYD:$RECAMERA_HOST:$DEVICE_PORT_TTYD" \
  -L "$TUNNEL_PORT_DEBUG:$RECAMERA_HOST:$DEVICE_PORT_DEBUG" \
  "$OPENWRT_SSH_TARGET" >>"$LOG_FILE" 2>&1 &
pid=$!
echo "$pid" > "$PID_FILE"
# Give the backgrounded ssh a brief moment to bind or fail.
sleep 1
if ! kill -0 "$pid" 2>/dev/null; then
  warn "tunnel process exited immediately; see $LOG_FILE"
  cat "$LOG_FILE" >&2 2>/dev/null || true
  rm -f "$PID_FILE"
  exit 1
fi

ok=yes
for port in "$TUNNEL_PORT_HTTP" "$TUNNEL_PORT_NODERED" "$TUNNEL_PORT_TTYD" "$TUNNEL_PORT_DEBUG"; do
  if ! is_port_listening "$port"; then
    warn "port $port not listening"
    ok=no
  fi
done
[ "$ok" = "yes" ] || exit 1

note "tunnels up (pid $pid). forwards:"
printf '  %-6s -> %s:%s\n' "$TUNNEL_PORT_HTTP" "$RECAMERA_HOST" "$DEVICE_PORT_HTTP"
printf '  %-6s -> %s:%s\n' "$TUNNEL_PORT_NODERED" "$RECAMERA_HOST" "$DEVICE_PORT_NODERED"
printf '  %-6s -> %s:%s\n' "$TUNNEL_PORT_TTYD" "$RECAMERA_HOST" "$DEVICE_PORT_TTYD"
printf '  %-6s -> %s:%s\n' "$TUNNEL_PORT_DEBUG" "$RECAMERA_HOST" "$DEVICE_PORT_DEBUG"
