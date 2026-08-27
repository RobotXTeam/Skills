#!/bin/sh
# Read-only preflight for reCamera live development.
# Does not write to the device and does not require device credentials.
#
# Environment overrides:
#   OPENWRT_SSH_TARGET   (default root@10.88.92.200)
#   RECAMERA_HOST        (default 192.168.42.1)
#   RECAMERA_USER        (default recamera)
#   RECAMERA_DIRECT      (auto|1|yes|true|0|no|false) transport selection;
#                          auto prefers a direct USB-RNDIS link and falls
#                          back to the OpenWrt jump
#   RECAMERA_PASSWORD    (optional; only used for remote SSH when keys unavailable)
#   OPENWRT_JUMP         (default OPENWRT_SSH_TARGET)
#   LOCAL_ONLY           (non-empty: skip remote checks)
#
# Read-only: never writes to the device. This check needs no credentials — it
# runs with SSH keys/BatchMode. The deploy scripts load RECAMERA_PASSWORD /
# RECAMERA_SUDO_PASSWORD from the environment or ~/.config/reweb/credentials.env
# when they need them (see lib.sh).

set -u

SKILL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SKILL_DIR/scripts/lib.sh"

OPENWRT_SSH_TARGET="${OPENWRT_SSH_TARGET:-root@10.88.92.200}"
RECAMERA_HOST="${RECAMERA_HOST:-192.168.42.1}"
RECAMERA_USER="${RECAMERA_USER:-recamera}"
OPENWRT_JUMP="${OPENWRT_JUMP:-$OPENWRT_SSH_TARGET}"
latch_transport

REPO=/home/steven/sscma-example-sg200x
WWW=$REPO/solutions/supervisor/www

fail=0
section() { printf '\n== %s ==\n' "$1"; }
check() {
  if "$@"; then
    printf '  ok: %s\n' "$*"
  else
    printf '  MISSING: %s\n' "$*"
    fail=1
  fi
}

section "repository"
[ -d "$REPO" ] && check test -d "$REPO/.git"
check test -f "$REPO/solutions/supervisor/CMakeLists.txt"
check test -f "$WWW/package.json"
check test -f "$WWW/vite.config.ts"
check test -f "$REPO/.claude/launch.json"
check test -f "$WWW/src/utils/deviceProxy.ts"

section "host toolchain"
command -v npm >/dev/null && check command -v npm
command -v node >/dev/null && check command -v node
command -v cmake >/dev/null && check command -v cmake
GCC=/home/steven/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-gcc
[ -x "$GCC" ] && check test -x "$GCC"
SDK=/home/steven/sg2002_recamera_emmc
[ -d "$SDK" ] && check test -d "$SDK"

section "local listeners"
for port in 5173 18080 18081 18082 18083; do
  if ss -ltn 2>/dev/null | grep -q ":$port\b"; then
    printf '  ok: local %s listening\n' "$port"
  else
    printf '  NOTE: local %s not listening (start tunnels/preview)\n' "$port"
  fi
done

if [ -n "${LOCAL_ONLY:-}" ]; then
  printf '\nLOCAL_ONLY set; skipping remote checks.\n'
  exit "$fail"
fi

section "openwrt reachability"
case "$TRANSPORT" in
  direct)
    printf '  ok: direct transport selected for %s (OpenWrt jump not used)\n' "$RECAMERA_HOST"
    ;;
  *)
    if ssh -o BatchMode=yes -o ConnectTimeout=6 "$OPENWRT_SSH_TARGET" true >/dev/null 2>&1; then
      printf '  ok: openwrt ssh (%s)\n' "$OPENWRT_SSH_TARGET"
    else
      printf '  MISSING: openwrt ssh (%s)\n' "$OPENWRT_SSH_TARGET"
      fail=1
    fi
    ;;
esac

section "device reachability"
dev_cmd() {
  if [ "$TRANSPORT" = "direct" ]; then
    curl -sS --max-time 6 -o /tmp/pf.out -w '%{http_code}' "http://$RECAMERA_HOST/api/version" 2>/dev/null
  else
    ssh -o BatchMode=yes -o ConnectTimeout=8 "$OPENWRT_JUMP" \
      "curl -sS --max-time 6 -o /tmp/pf.out -w '%{http_code}' http://$RECAMERA_HOST/api/version" 2>/dev/null
  fi
}
code="$(dev_cmd || true)"
if [ "$code" = "200" ]; then
  printf '  ok: device api version -> '
  if [ "$TRANSPORT" = "direct" ]; then
    cat /tmp/pf.out 2>/dev/null | head -c 200
  else
    ssh -o BatchMode=yes -o ConnectTimeout=6 "$OPENWRT_JUMP" 'cat /tmp/pf.out 2>/dev/null' 2>/dev/null | head -c 200
  fi
  printf '\n'
else
  printf '  NOTE: device api/version returned %s (tunnels may be down or device busy)\n' "${code:-none}"
fi

if [ "$TRANSPORT" != "direct" ]; then
  if ssh -o BatchMode=yes -o ConnectTimeout=6 "$OPENWRT_JUMP" \
    "ping -c1 -W2 $RECAMERA_HOST >/dev/null 2>&1" 2>/dev/null; then
    printf '  ok: openwrt can ping device %s\n' "$RECAMERA_HOST"
  else
    printf '  NOTE: openwrt cannot ping device %s\n' "$RECAMERA_HOST"
  fi
fi

exit "$fail"
