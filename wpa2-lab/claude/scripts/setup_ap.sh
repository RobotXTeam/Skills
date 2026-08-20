#!/bin/bash
# setup_ap.sh — 在 AP 主机(seeed 192.168.2.113)上启动 WPA2-CCMP 热点
# 用法: bash setup_ap.sh [密码]   不传密码则随机生成 8 位
# 合法自有环境: 仅用于 Steven 自己的设备
set -e

WIFI="${WIFI:-wlp4s0}"
AP_IP="${AP_IP:-192.168.7.1}"
SSID="${SSID:-LAB-WPA2-TEST}"
CHANNEL="${CHANNEL:-6}"
WORKDIR="${WORKDIR:-/home/seeed/wpa2_lab}"

# 密码: 传参用之, 否则随机 8 位字母数字
if [ -n "$1" ]; then
  PASS="$1"
else
  PASS=$(head -c 32 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8)
fi

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# hostapd 配置: WPA2-PSK CCMP
cat > hostapd.conf << EOF
interface=$WIFI
driver=nl80211
ssid=$SSID
hw_mode=g
channel=$CHANNEL
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASS
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
EOF

# dnsmasq 配置
cat > dnsmasq.conf << EOF
interface=$WIFI
bind-interfaces
listen-address=$AP_IP
dhcp-range=192.168.7.10,192.168.7.50,12h
dhcp-option=3,$AP_IP
dhcp-option=6,$AP_IP
EOF

# 让 NetworkManager 放手
sudo nmcli dev set "$WIFI" managed no 2>/dev/null || true
sudo nmcli dev disconnect "$WIFI" 2>/dev/null || true
sleep 1

sudo ip link set "$WIFI" down
sudo ip addr flush dev "$WIFI"
sudo ip addr add "$AP_IP/24" dev "$WIFI"
sudo ip link set "$WIFI" up
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null

sudo pkill -f "dnsmasq.*$WORKDIR" 2>/dev/null || true
sudo dnsmasq --conf-file="$WORKDIR/dnsmasq.conf" --pid-file="$WORKDIR/dnsmasq.pid"

# 重要: 诚实攻击者模式不要加 -dd -K (会dump内部PMK/PTK, 等于作弊)
sudo pkill hostapd 2>/dev/null || true
sudo hostapd -B -P "$WORKDIR/hostapd.pid" -f "$WORKDIR/hostapd.log" "$WORKDIR/hostapd.conf"
sleep 2

echo "=== WPA2 热点就绪 ==="
echo "SSID: $SSID"
echo "密码: $PASS"
echo "BSSID: $(ip link show $WIFI | awk '/link\/ether/{print $2}')"
echo "信道: $CHANNEL  网段: $AP_IP/24"
echo "配置目录: $WORKDIR"
sudo iw dev "$WIFI" info | grep -E "type|ssid|channel"
