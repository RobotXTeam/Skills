#!/usr/bin/env bash
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ssh_cmd="$skill_dir/environments/seeed-recamera/scripts/recamera_ssh.sh"

echo "== seeed =="
sshpass -p "${SEEED_PASSWORD:-0}" ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 "${SEEED_ALIAS:-seeed}" \
  'hostname; whoami; ip -4 -br addr | sed -n "1,20p"; echo; curl -I --connect-timeout 3 --max-time 5 http://192.168.42.1 2>/dev/null | sed -n "1,8p"; nc -vz -w 3 192.168.42.1 22 2>&1 || true'

echo
echo "== recamera =="
"$ssh_cmd" 'hostname; whoami; uname -a; echo; cat /etc/os-release 2>/dev/null || true; echo; df -h / /home /userdata 2>/dev/null; echo; ls -1 /etc/init.d | grep -E "node-red|sscma|ttyd|sshd|supervisor" || true; echo; find /home/recamera /userdata -maxdepth 2 -type f \( -name "*.cvimodel" -o -name "face_udp" -o -name "recamera_benchmark" \) 2>/dev/null | sort'

echo
echo "== local toolchain =="
for p in \
  /home/steven/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-gcc \
  /home/steven/sg2002_recamera_emmc \
  /home/steven/sscma-example-sg200x
do
  if [ -e "$p" ]; then
    echo "OK $p"
  else
    echo "MISSING $p"
  fi
done
