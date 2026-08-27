#!/bin/sh
# Run a non-interactive command on the reCamera (direct USB-RNDIS link or
# through OpenWrt, depending on the latched transport).
# Usage:
#   recamera-ssh.sh 'command...'
# Credentials come from SSH agent/keys or RECAMERA_PASSWORD env var.

set -u

SKILL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SKILL_DIR/scripts/lib.sh"
latch_transport

[ $# -gt 0 ] || { echo "usage: $0 'command...'" >&2; exit 2; }
recamera_ssh "$@"
