#!/bin/sh
# Copy files to the reCamera through OpenWrt.
# Usage:
#   recamera-scp.sh local1 [local2 ...] remote:path

set -u

SKILL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SKILL_DIR/scripts/lib.sh"

[ $# -ge 2 ] || { echo "usage: $0 local... remote:path" >&2; exit 2; }
recamera_scp "$@"
