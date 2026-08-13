# Shared library for reweb scripts.
# Kept POSIX sh on purpose: these scripts run from plain host shells.
#
# Credential policy:
#   No password is written into this file, generated configs, or logs.
#   Use SSH agent/keys. RECAMERA_PASSWORD/RECAMERA_SUDO_PASSWORD are read
#   only as process environment variables by the functions below.

SKILL_DIR="${SKILL_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
REPO="${REPO:-/home/steven/sscma-example-sg200x}"
WWW_DIR="$REPO/solutions/supervisor/www"
LAUNCH_JSON="$REPO/.claude/launch.json"

OPENWRT_SSH_TARGET="${OPENWRT_SSH_TARGET:-root@10.88.92.200}"
RECAMERA_HOST="${RECAMERA_HOST:-192.168.2.102}"
RECAMERA_USER="${RECAMERA_USER:-recamera}"
OPENWRT_JUMP="${OPENWRT_JUMP:-$OPENWRT_SSH_TARGET}"

# Device credentials (Steven's setup). These are the login password and the
# sudo password for the recamera account; the UI login uses the same value.
# Supplied here so /reweb sessions work without re-prompting. Override at run
# time by exporting RECAMERA_PASSWORD / RECAMERA_SUDO_PASSWORD if they change.
RECAMERA_PASSWORD="${RECAMERA_PASSWORD:-recamera.1}"
RECAMERA_SUDO_PASSWORD="${RECAMERA_SUDO_PASSWORD:-recamera.1}"

# Tunnel forwards kept in sync with vite.config.ts and deviceProxy.ts.
TUNNEL_PORT_HTTP="${TUNNEL_PORT_HTTP:-18080}"
TUNNEL_PORT_NODERED="${TUNNEL_PORT_NODERED:-18081}"
TUNNEL_PORT_TTYD="${TUNNEL_PORT_TTYD:-18082}"
TUNNEL_PORT_DEBUG="${TUNNEL_PORT_DEBUG:-18083}"
DEVICE_PORT_HTTP="${DEVICE_PORT_HTTP:-80}"
DEVICE_PORT_NODERED="${DEVICE_PORT_NODERED:-1880}"
DEVICE_PORT_TTYD="${DEVICE_PORT_TTYD:-9090}"
DEVICE_PORT_DEBUG="${DEVICE_PORT_DEBUG:-8001}"

RUN_DIR="${RUN_DIR:-${XDG_RUNTIME_DIR:-/tmp}/reweb}"
PID_FILE="$RUN_DIR/tunnels.pid"
LOG_FILE="$RUN_DIR/tunnels.log"

note() { printf '[reweb] %s\n' "$*"; }
warn() { printf '[reweb] WARNING: %s\n' "$*" >&2; }
die() { printf '[reweb] ERROR: %s\n' "$*" >&2; exit 1; }

require_var() {
  name="$1"
  eval "val=\${$name:-}"
  [ -n "$val" ] || die "$name is not set"
}

ensure_run_dir() {
  mkdir -p "$RUN_DIR" 2>/dev/null || die "cannot create $RUN_DIR"
}

listener_pid_for_port() {
  port="$1"
  ss -ltnp 2>/dev/null | awk -v p=":$port" '$4 ~ p {split($0, a, "users:((\"|,))"); gsub(".*pid=", "", a[2]); print a[2]; exit}'
}

is_port_listening() {
  port="$1"
  ss -ltn 2>/dev/null | grep -q ":$port\b"
}

# Build the remote SSH command with optional sshpass fallback. Never echoes
# a password. Caller decides whether to use BatchMode.
ssh_cmd_base() {
  set -- -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new
  if [ -n "${RECAMERA_PASSWORD:-}" ] && command -v sshpass >/dev/null 2>&1; then
    # sshpass consumes the password via stdin to avoid it appearing in argv.
    printf 'sshpass -e ssh %s ' "$*"
  else
    printf 'ssh %s ' "$*"
  fi
}

# Run a command on the reCamera through OpenWrt. Uses a ProxyCommand through
# OpenWrt; optional device credentials are supplied through SSHPASS, never argv.
recamera_ssh() {
  target="$RECAMERA_USER@$RECAMERA_HOST"
  if [ -n "${RECAMERA_PASSWORD:-}" ] && command -v sshpass >/dev/null 2>&1; then
    SSHPASS="$RECAMERA_PASSWORD" sshpass -e ssh -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=8 \
      -o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 $OPENWRT_JUMP nc $RECAMERA_HOST 22" \
      "$target" "$@"
  else
    ssh -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=8 \
      -o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 $OPENWRT_JUMP nc $RECAMERA_HOST 22" \
      "$target" "$@"
  fi
}

# Copy files to the reCamera through OpenWrt.
recamera_scp() {
  target="$RECAMERA_USER@$RECAMERA_HOST"
  if [ -n "${RECAMERA_PASSWORD:-}" ] && command -v sshpass >/dev/null 2>&1; then
    SSHPASS="$RECAMERA_PASSWORD" sshpass -e scp -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=8 \
      -o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 $OPENWRT_JUMP nc $RECAMERA_HOST 22" \
      "$@"
  else
    scp -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=8 \
      -o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 $OPENWRT_JUMP nc $RECAMERA_HOST 22" \
      "$@"
  fi
}

# Run a privileged command on the reCamera. Commands are base64 encoded before
# transport so shell metacharacters and quotes cannot corrupt the SSH command.
recamera_sudo() {
  recamera_sudo_sh "$*"
}

recamera_sudo_sh() {
  cmd="$1"
  encoded="$(printf '%s' "$cmd" | base64 | tr -d '\n')"
  remote="sudo -S sh -c \"\$(printf '%s' '$encoded' | base64 -d)\""
  if [ -n "${RECAMERA_SUDO_PASSWORD:-}" ]; then
    printf '%s\n' "$RECAMERA_SUDO_PASSWORD" | recamera_ssh "$remote" 2>/dev/null
  else
    recamera_ssh "$remote"
  fi
}
