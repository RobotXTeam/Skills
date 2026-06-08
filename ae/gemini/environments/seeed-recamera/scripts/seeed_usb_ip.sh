#!/usr/bin/env bash
set -euo pipefail

SEEED_ALIAS="${SEEED_ALIAS:-seeed}"
SEEED_PASSWORD="${SEEED_PASSWORD:-0}"

sshpass -p "$SEEED_PASSWORD" ssh \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=8 \
  "$SEEED_ALIAS" \
  "ip -4 -brief addr | awk '/192[.]168[.]42[.]/{sub(/\\/.*/, \"\", \$3); print \$3; exit}'"
