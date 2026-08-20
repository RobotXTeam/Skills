#!/bin/bash
# stop_ap.sh — 停止 AP, 把无线口交还 NetworkManager
# 用法: bash stop_ap.sh
WIFI="${WIFI:-wlp4s0}"
WORKDIR="${WORKDIR:-/home/seeed/wpa2_lab}"

sudo pkill hostapd 2>/dev/null || true
sudo pkill -f "dnsmasq.*$WORKDIR" 2>/dev/null || true
sleep 1

sudo ip link set "$WIFI" down
sudo ip addr flush dev "$WIFI"
sudo iw dev "$WIFI" set type managed 2>/dev/null || true
sudo ip link set "$WIFI" up
sudo nmcli dev set "$WIFI" managed yes 2>/dev/null || true

echo "AP 已停, $WIFI 交还 NetworkManager"
iw dev "$WIFI" info 2>&1 | grep -E "type|ssid"
