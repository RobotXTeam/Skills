# Shared library for reweb scripts.
# Kept POSIX sh on purpose: these scripts run from plain host shells.
#
# Credential policy:
#   No password is written into this file, generated configs, or logs.
#   RECAMERA_PASSWORD/RECAMERA_SUDO_PASSWORD are read ONLY from the process
#   environment or from the operator-local credentials file
#   (~/.config/reweb/credentials.env), which lives outside this skill and the
#   repository and is never committed to git. Neither value is ever printed or
#   logged. Deploys that need the passwords call require_credentials() and fail
#   with a clear message when no credential source is configured.

SKILL_DIR="${SKILL_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
REPO="${REPO:-/home/steven/sscma-example-sg200x}"
WWW_DIR="$REPO/solutions/supervisor/www"
LAUNCH_JSON="$REPO/.claude/launch.json"

OPENWRT_SSH_TARGET="${OPENWRT_SSH_TARGET:-root@10.88.92.200}"
RECAMERA_HOST="${RECAMERA_HOST:-192.168.42.1}"
RECAMERA_USER="${RECAMERA_USER:-recamera}"
OPENWRT_JUMP="${OPENWRT_JUMP:-$OPENWRT_SSH_TARGET}"

RUN_DIR="${RUN_DIR:-${XDG_RUNTIME_DIR:-/tmp}/reweb}"
PID_FILE="$RUN_DIR/tunnels.pid"
LOG_FILE="$RUN_DIR/tunnels.log"

# Transport selection. The 192.168.42.1 reCamera is attached through USB-RNDIS
# and is reachable directly from the workstation (and not through OpenWrt);
# the older device sits behind an OpenWrt jump host. Both paths stay supported:
#   RECAMERA_DIRECT=auto        probe the route table, prefer direct (default)
#   RECAMERA_DIRECT=1|yes|true  force direct SSH to RECAMERA_HOST
#   RECAMERA_DIRECT=0|no|false  force the OpenWrt ProxyCommand jump
# The decision is latched per host under $RUN_DIR so chained invocations
# (deploy -> preflight -> lib -> ssh) share one transport.
TRANSPORT_LATCH_DIR="$RUN_DIR"
RECAMERA_DIRECT="${RECAMERA_DIRECT:-auto}"

# --- Credentials ------------------------------------------------------------
# No hardcoded defaults. Precedence: process environment, then the operator-local
# credentials file if present. A value left empty means "no password configured":
# the SSH wrappers then fall back to agent/key-based auth, and require_credentials()
# below errors out when a deploy actually needs the passwords.
CREDENTIALS_FILE="${CREDENTIALS_FILE:-$HOME/.config/reweb/credentials.env}"
_cred_pwd="${RECAMERA_PASSWORD:-}"
_cred_sudo="${RECAMERA_SUDO_PASSWORD:-}"
if [ -n "$CREDENTIALS_FILE" ] && [ -r "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE" 2>/dev/null || true
fi
RECAMERA_PASSWORD="${_cred_pwd:-$RECAMERA_PASSWORD}"
RECAMERA_SUDO_PASSWORD="${_cred_sudo:-$RECAMERA_SUDO_PASSWORD}"

# Tunnel forwards kept in sync with vite.config.ts and deviceProxy.ts.
TUNNEL_PORT_HTTP="${TUNNEL_PORT_HTTP:-18080}"
TUNNEL_PORT_NODERED="${TUNNEL_PORT_NODERED:-18081}"
TUNNEL_PORT_TTYD="${TUNNEL_PORT_TTYD:-18082}"
TUNNEL_PORT_DEBUG="${TUNNEL_PORT_DEBUG:-18083}"
DEVICE_PORT_HTTP="${DEVICE_PORT_HTTP:-80}"
DEVICE_PORT_NODERED="${DEVICE_PORT_NODERED:-1880}"
DEVICE_PORT_TTYD="${DEVICE_PORT_TTYD:-9090}"
DEVICE_PORT_DEBUG="${DEVICE_PORT_DEBUG:-8001}"

note() { printf '[reweb] %s\n' "$*"; }
warn() { printf '[reweb] WARNING: %s\n' "$*" >&2; }
die() { printf '[reweb] ERROR: %s\n' "$*" >&2; exit 1; }

require_var() {
  name="$1"
  eval "val=\${$name:-}"
  [ -n "$val" ] || die "$name is not set"
}

# Fail loudly when a deploy needs device passwords but none are configured.
# The message names both supported sources; it never reveals a value.
require_credentials() {
  if [ -z "$RECAMERA_PASSWORD" ]; then
    die "device login password not configured: export RECAMERA_PASSWORD, or add it to $CREDENTIALS_FILE"
  fi
  if [ -z "$RECAMERA_SUDO_PASSWORD" ]; then
    die "device sudo password not configured: export RECAMERA_SUDO_PASSWORD, or add it to $CREDENTIALS_FILE"
  fi
}

ensure_run_dir() {
  mkdir -p "$TRANSPORT_LATCH_DIR" 2>/dev/null || die "cannot create $TRANSPORT_LATCH_DIR"
}

# Resolve and latch the transport for this host. The result (direct or
# openwrt-jump) is sticky for up to 12h per host so all chained calls use the
# same path; it can be refreshed by deleting $RUN_DIR/transport.<host>.
latch_transport() {
  ensure_run_dir
  host="$(printf '%s\n' "$RECAMERA_HOST" | sed 's/[^A-Za-z0-9._-]//g')"
  latch_file="$TRANSPORT_LATCH_DIR/transport.$host"
  latch=""
  if [ -f "$latch_file" ] && ! find "$latch_file" -mmin +720 | grep -q .; then
    latch="$(cat "$latch_file" 2>/dev/null || true)"
  fi
  case "$latch" in
    direct|openwrt-jump) ;;
    *)
      case "$RECAMERA_DIRECT" in
        1|yes|true) latch="direct" ;;
        0|no|false) latch="openwrt-jump" ;;
        *)
          # auto: direct is assumed when the host has an on-link route to the
          # device, which is how a USB-RNDIS-attached reCamera shows up.
          if ip route get "$RECAMERA_HOST" >/dev/null 2>&1; then
            latch="direct"
          else
            latch="openwrt-jump"
          fi
          ;;
      esac
      printf '%s\n' "$latch" > "$latch_file" 2>/dev/null || true
      ;;
  esac
  TRANSPORT="$latch"
  case "$latch" in
    direct) RECAMERA_DIRECT=1 ;;
    *) RECAMERA_DIRECT=0 ;;
  esac
}

listener_pid_for_port() {
  port="$1"
  ss -ltnp 2>/dev/null | awk -v p=":$port" '$4 ~ p {split($0, a, "users:((\"|,))"); gsub(".*pid=", "", a[2]); print a[2]; exit}'
}

is_port_listening() {
  port="$1"
  ss -ltn 2>/dev/null | grep -q ":$port\b"
}

# Run a command on the reCamera (direct USB-RNDIS link or through OpenWrt,
# per the latched transport). Optional device credentials are supplied through
# SSHPASS, never argv. Publickey is disabled on the password path so agent
# keys cannot burn the device's MaxAuthTries budget before the password runs.
recamera_ssh() {
  target="$RECAMERA_USER@$RECAMERA_HOST"
  if [ -n "${RECAMERA_PASSWORD:-}" ] && command -v sshpass >/dev/null 2>&1; then
    if [ "$TRANSPORT" = "direct" ]; then
      SSHPASS="$RECAMERA_PASSWORD" sshpass -e ssh -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=8 -o PubkeyAuthentication=no "$target" "$@"
    else
      SSHPASS="$RECAMERA_PASSWORD" sshpass -e ssh -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=8 -o PubkeyAuthentication=no \
        -o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 $OPENWRT_JUMP nc $RECAMERA_HOST 22" \
        "$target" "$@"
    fi
  elif [ "$TRANSPORT" = "direct" ]; then
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 "$target" "$@"
  else
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 \
      -o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 $OPENWRT_JUMP nc $RECAMERA_HOST 22" \
      "$target" "$@"
  fi
}

# Copy files to the reCamera (direct USB-RNDIS link or through OpenWrt, per
# the latched transport). Modern OpenSSH scp already transfers over the SFTP
# subsystem, so no extra flag is needed (the old `-s sftp` was invalid on
# OpenSSH >= 9 and aborted the upload with "stat local sftp: No such file").
recamera_scp() {
  if [ -n "${RECAMERA_PASSWORD:-}" ] && command -v sshpass >/dev/null 2>&1; then
    if [ "$TRANSPORT" = "direct" ]; then
      SSHPASS="$RECAMERA_PASSWORD" sshpass -e scp -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=8 -o PubkeyAuthentication=no "$@"
    else
      SSHPASS="$RECAMERA_PASSWORD" sshpass -e scp -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=8 -o PubkeyAuthentication=no \
        -o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 $OPENWRT_JUMP nc $RECAMERA_HOST 22" \
        "$@"
    fi
  elif [ "$TRANSPORT" = "direct" ]; then
    scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 "$@"
  else
    scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 \
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

# --- Device backup / retention helpers --------------------------------------
# Backup namespace: web and supervisor deploys use distinct names under the
# same timestamp so they can never clobber each other's snapshots.
BACKUP_BASE="${BACKUP_BASE:-/userdata/local/backups}"

# Host-side last-known-good snapshots (git-ignored via $REPO/.gitignore): a
# recovery copy that survives even a device that can no longer be reached.
LOCAL_BACKUP_DIR="${LOCAL_BACKUP_DIR:-$REPO/.reweb-backups}"

MODE_FILE=/userdata/local/apps/mode

# Free space (KB) on the device partition that holds the backup directory.
device_free_kb() {
  recamera_ssh "df -P /userdata/local 2>/dev/null | awk 'NR==2 {print \$4}'" 2>/dev/null || true
}

# Fail early with a clear message when the device has too little space.
require_device_space() {
  need_kb="$1"
  where="$2"
  free_kb="$(device_free_kb)"
  case "$free_kb" in
    '')
      warn "could not read device disk space on $where; continuing without the space check"
      ;;
    *[!0-9]*)
      warn "unexpected device disk-space output on $where; continuing without the space check"
      ;;
    *)
      if [ "$free_kb" -lt "$need_kb" ]; then
        die "insufficient device disk space on $where: need ~${need_kb} KB free, have ${free_kb} KB"
      fi
      ;;
  esac
}

# Restore /userdata/local/apps/mode from a backup's mode.before snapshot.
restore_mode() {
  backup_dir="$1"
  if ! recamera_sudo_sh "[ -f '$backup_dir/mode.before' ] && cp -a '$backup_dir/mode.before' '$MODE_FILE'"; then
    warn "could not restore mode from $backup_dir/mode.before"
    return 1
  fi
  return 0
}

# Prune old backups of the current transaction's category while never deleting
# its newly-created backup. Web and Supervisor retention are independent and do
# not touch one-off runtime/SFTP/asset snapshots.
prune_backups() {
  keep="${1:-5}"
  protect="${2:-}"
  protect_name="${protect##*/}"
  case "$protect_name" in
    reweb-*-web) pattern='reweb-*-web' ;;
    reweb-*-supervisor) pattern='reweb-*-supervisor' ;;
    *) warn "backup pruning skipped: unrecognized protected backup $protect_name"; return 0 ;;
  esac
  recamera_sudo_sh "cd '$BACKUP_BASE' 2>/dev/null || exit 0; ls -1d $pattern 2>/dev/null | sort -r | awk -v keep='$keep' -v protect='$protect_name' '\$0 == protect { next } kept < keep { kept++; next } { print }' | { while read d; do rm -rf -- \"\$d\" 2>/dev/null || true; done; }" || warn "could not prune $pattern backups in $BACKUP_BASE"
}

# Snapshot a freshly built artifact to the host-side backup dir (git-ignored),
# keeping the most recent 5 local copies.
local_backup() {
  sub="$1"
  src="$2"
  label="${3:-$(date +%Y%m%d-%H%M%S)}"
  dest_dir="$LOCAL_BACKUP_DIR/$sub"
  mkdir -p "$dest_dir" 2>/dev/null || { warn "cannot create $dest_dir; skipping local backup"; return 0; }
  rm -rf -- "$dest_dir/$sub-$label" 2>/dev/null || true
  if ! cp -a "$src" "$dest_dir/$sub-$label" 2>/dev/null; then
    warn "local backup failed: $src -> $dest_dir/$sub-$label"
    return 0
  fi
  note "local backup: $dest_dir/$sub-$label"
  # Snapshot names embed a zero-padded timestamp, so name sort is chronological
  # and deterministic (unlike ls -t when two snapshots share an mtime).
  # Descending sort keeps the newest 5; -d keeps directory snapshots from being
  # descended into by ls.
  old="$(ls -1d "$dest_dir"/"$sub"-* 2>/dev/null | sort -r | tail -n +6 || true)"
  for d in $old; do rm -rf -- "$d" 2>/dev/null || true; done
}
