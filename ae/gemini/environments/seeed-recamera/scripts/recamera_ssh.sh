#!/usr/bin/env bash
set -euo pipefail

SEEED_ALIAS="${SEEED_ALIAS:-seeed}"
SEEED_PASSWORD="${SEEED_PASSWORD:-0}"
RECAMERA_HOST="${RECAMERA_HOST:-192.168.42.1}"
RECAMERA_USER="${RECAMERA_USER:-recamera}"

if [ -n "${RECAMERA_PASSWORD:-}" ]; then
  RECAMERA_PASSWORDS=("$RECAMERA_PASSWORD")
else
  RECAMERA_PASSWORDS=("recamera.1" "kkk000++")
fi

if [ "$#" -eq 0 ]; then
  set -- "hostname; whoami"
fi

status=1
for password in "${RECAMERA_PASSWORDS[@]}"; do
  if sshpass -p "$password" ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    -o PreferredAuthentications=password,keyboard-interactive \
    -o PubkeyAuthentication=no \
    -o ProxyCommand="sshpass -p '$SEEED_PASSWORD' ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 '$SEEED_ALIAS' nc '$RECAMERA_HOST' 22" \
    "$RECAMERA_USER@dummy" "$@"; then
    exit 0
  fi
  status=$?
done

exit "$status"
