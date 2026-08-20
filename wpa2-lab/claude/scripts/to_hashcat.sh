#!/bin/bash
# to_hashcat.sh — 把 airodump 抓的 pcap 转成 hashcat mode 22000 (WPA-PMKID-EAPOL)
# 用法: bash to_hashcat.sh <input.pcap> <output.hc22000>
# 需要: hcxtools (apt install hcxtools)
set -e
IN="${1:?usage: to_hashcat.sh input.pcap output.hc22000}"
OUT="${2:?need output path}"

if ! command -v hcxpcapngtool >/dev/null 2>&1; then
  echo "需要 hcxtools. 安装: sudo apt install hcxtools" >&2
  exit 1
fi

# 提取所有 EAPOL/PMKID 到 hc22000 格式
hcxpcapngtool -o "$OUT" "$IN"

if [ ! -s "$OUT" ]; then
  echo "未提取到 hash — pcap 里没有合法握手或 PMKID" >&2
  exit 1
fi

echo "hash 写入 $OUT"
echo "爆破示例:"
echo "  # 纯8位数字"
echo "  hashcat -m 22000 $OUT ?d?d?d?d?d?d?d?d"
echo "  # 字典"
echo "  hashcat -m 22000 -a 0 $OUT wordlist.txt"
echo "  # 规则增强 (常用弱密码变形)"
echo "  hashcat -m 22000 -a 0 $OUT wordlist.txt -r /usr/share/hashcat/rules/rockyou-30000.rule"
