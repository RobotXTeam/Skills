#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: recamera_scp_to.sh LOCAL... REMOTE_PATH" >&2
  exit 2
fi

args=("$@")
remote_path="${args[$#-1]}"
unset 'args[$#-1]'

SEEED_ALIAS="${SEEED_ALIAS:-seeed}"
SEEED_PASSWORD="${SEEED_PASSWORD:-0}"
RECAMERA_HOST="${RECAMERA_HOST:-192.168.42.1}"
RECAMERA_USER="${RECAMERA_USER:-recamera}"
RECAMERA_PASSWORD="${RECAMERA_PASSWORD:-recamera.1}"

sshpass -p "$RECAMERA_PASSWORD" scp \
  -O \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=10 \
  -o PreferredAuthentications=password,keyboard-interactive \
  -o PubkeyAuthentication=no \
  -o ProxyCommand="sshpass -p '$SEEED_PASSWORD' ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 '$SEEED_ALIAS' nc '$RECAMERA_HOST' 22" \
  "${args[@]}" "$RECAMERA_USER@dummy:$remote_path"
