#!/usr/bin/env bash
set -euo pipefail

SEEED_ALIAS="${SEEED_ALIAS:-seeed}"
SEEED_PASSWORD="${SEEED_PASSWORD:-0}"
RECAMERA_HOST="${RECAMERA_HOST:-192.168.42.1}"
RECAMERA_USER="${RECAMERA_USER:-recamera}"
RECAMERA_PASSWORD="${RECAMERA_PASSWORD:-recamera.1}"

if [ "$#" -eq 0 ]; then
  set -- "hostname; whoami"
fi

sshpass -p "$RECAMERA_PASSWORD" ssh \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=10 \
  -o PreferredAuthentications=password,keyboard-interactive \
  -o PubkeyAuthentication=no \
  -o ProxyCommand="sshpass -p '$SEEED_PASSWORD' ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 '$SEEED_ALIAS' nc '$RECAMERA_HOST' 22" \
  "$RECAMERA_USER@dummy" "$@"
