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

if [ -n "${RECAMERA_PASSWORD:-}" ]; then
  RECAMERA_PASSWORDS=("$RECAMERA_PASSWORD")
else
  RECAMERA_PASSWORDS=("recamera.1" "kkk000++")
fi

status=1
for password in "${RECAMERA_PASSWORDS[@]}"; do
  if sshpass -p "$password" scp \
    -O \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    -o PreferredAuthentications=password,keyboard-interactive \
    -o PubkeyAuthentication=no \
    -o ProxyCommand="sshpass -p '$SEEED_PASSWORD' ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 '$SEEED_ALIAS' nc '$RECAMERA_HOST' 22" \
    "${args[@]}" "$RECAMERA_USER@dummy:$remote_path"; then
    exit 0
  fi
  status=$?
done

exit "$status"
