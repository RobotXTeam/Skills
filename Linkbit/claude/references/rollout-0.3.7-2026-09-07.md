# Linkbit 0.3.7 Rollout (2026-09-07)

## Versions & repos

- Source: github.com/RobotXTeam/Linkbit (cloned at ~/work/Linkbit; head c90603c "feat: add share and join invitations").
- Built 0.3.7: amd64 via `GO=/usr/local/go/bin/go ./scripts/build-linux-amd64.sh` (script needs GO env var; system go at /usr/local/go/bin/go; web vite build runs first; modules via GOPROXY=goproxy.cn + HTTPS_PROXY=127.0.0.1:7897).
- arm64 agent: `GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o bin/arm64/linkbit-agent ./cmd/linkbit-agent`.

## Controller / relay host (aliyun)

- SSH: `sshpass -p ',/Q+AhPq_pDk6u.' ssh root@100.74.164.102` (tailscale IP; ssh config alias aliyun-cloud points at STALE 10.88.21.78 — update it).
- Public: http://120.79.155.227 (nginx :80 → controller 127.0.0.1:8080; controller binds LOOPBACK only).
- Admin key: LINKBIT_BOOTSTRAP_API_KEY in /etc/linkbit/controller.env on aliyun.
- Deploy order matters: `systemctl stop linkbit-controller linkbit-relay` BEFORE scp (Text file busy), then chmod +x, start. Backups kept as /opt/linkbit/*.bak-<ts>.
- sshd on aliyun rate-limits: rapid consecutive password logins get kex reset — batch operations into ONE ssh session, sleep between retries.

## Devices (controller /api/v1/devices, 8 enrolled)

seeed-reserver 10.88.106.235 | aliyun-cloud 10.88.21.78 | radxa-cubie-a7a 10.88.78.146 | orangepi 10.88.14.46 | seeed 10.88.222.222 | steven 10.88.226.245 | friendlywrt 10.88.92.200 | steven-ubuntu(=Qiang) 10.88.235.251.

## Mesh vs relay truth

- WireGuard mesh = UDP to hub endpoint 120.79.155.227:443. On CGNAT egress (e.g. Qiang egress via F50 5G) UDP hole-punch fails → mesh pings FAIL while **TCP relay still works** (forward via controller HTTPS). Mesh recovers when a UDP-friendly path (home broadband) returns. Not a bug.
- TCP relay interop proof: Qiang `sshpass -p 1 ssh -p 10023 steven@127.0.0.1` (service linkbit-forward-steven-remote-ssh).

## Agent upgrade one-liner pattern

scp new binary to /tmp → `sudo -S bash -c 'systemctl stop linkbit-agent; mv /tmp/linkbit-agent.new /usr/local/bin/linkbit-agent; chmod +x …; systemctl start linkbit-agent'`. Arch per device: steven/seeed/aliyun/Qiang=amd64; friendlywrt/orangepi/radxa=arm64.

## Status refresh 2026-09-09

- Fleet online on 0.3.7 (6): steven-ubuntu(Qiang), steven(remote), orangepi, friendlywrt, aliyun-cloud, seeed-reserver(online but STILL OLD agent — only reachable from its own network; upgrade pending).
- Offline: radxa-cubie-a7a (since 08-22; unreachable even via friendlywrt LAN jump 192.168.2.192 → box down/offline), seeed (since 09-07; 192.168.2.113 unreachable from friendlywrt → down).
- **Mesh (WG) never handshakes from Qiang on ANY egress**: 09-06 via F50 5G CGNAT and 09-09 via home broadband (new subnet 192.168.178.x) both fail; `wg show linkbit0 latest-handshakes` = 0; tcpdump on aliyun shows ZERO UDP/443 arrivals during mesh pings → path/ISP drops UDP 443 outbound. Hub side verified healthy (linkbit-hub listening UDP 443, ufw inactive, no iptables block). Conclusion: **TCP relay is the only working interconnect from Qiang; treat mesh as unavailable until a UDP-friendly egress is proven**. Mesh-dependent ops (mesh pings, wg-only paths) deferred; relay forwards (e.g. 10023→steven:22) are the sanctioned path.
- Qiang home WiFi subnet changed 09-06→09-09: 192.168.26.0/24 → 192.168.178.0/24 (gw .214). SSH inventory LAN IPs for Qiang-adjacent hosts unaffected.
