# Steven Device Runbook

This records the successful 2026-04-29 installation path for the user's remote Ubuntu device.

## Final state

- Controller: `http://120.79.155.227`
- Remote Linkbit device name: `steven`
- Remote Linkbit virtual IP after rename: `10.88.226.245`
- Remote agent state path: `/var/lib/linkbit/agent-state.json`
- Remote health interval: `LINKBIT_HEALTH_SECONDS=300`
- Remote service: `linkbit-agent.service` enabled and active
- Local forward service: `linkbit-forward-steven-remote-ssh.service`
- Local SSH entry: `ssh -p 10023 steven@127.0.0.1`

`127.0.0.1:10022` was already occupied by another Linkbit forward, so this device uses local port `10023`.

## Working access path

Direct SSH to `steven@100.108.64.20` can be slow or unstable. The reliable path uses the existing local jump:

```bash
sshpass -p '1' ssh \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/tmp/linkbit_inner_known_hosts \
  -o ProxyCommand="sshpass -p 'pi' ssh -p 10022 \
    -o PreferredAuthentications=password \
    -o PubkeyAuthentication=no \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/tmp/linkbit_jump_known_hosts \
    root@127.0.0.1 nc %h %p" \
  steven@192.168.2.101 'hostname; id'
```

The jump path is:

- Local -> `root@127.0.0.1:10022`, password `pi`
- Jump -> `steven@192.168.2.101`, password `1`

## Install or reconfigure remote agent

Install dependencies:

```bash
sudo apt-get update
sudo apt-get install -y wireguard-tools iproute2 ca-certificates openssh-server
```

Upload current agent and installer:

```bash
scp bin/linkbit-agent steven@target:/tmp/linkbit/bin/linkbit-agent
scp deploy/install-agent.sh steven@target:/tmp/linkbit/deploy/install-agent.sh
```

Write `/etc/linkbit/agent.env`:

```env
LINKBIT_CONTROLLER_URL=http://120.79.155.227
LINKBIT_ENROLLMENT_KEY=<fresh-token>
LINKBIT_DEVICE_NAME=steven
LINKBIT_HEALTH_SECONDS=300
LINKBIT_WG_INTERFACE=linkbit0
LINKBIT_WG_DRY_RUN=false
LINKBIT_STATE_PATH=/var/lib/linkbit/agent-state.json
LINKBIT_TCP_RELAY_ENABLED=true
LINKBIT_RUN_ONCE=false
```

Start service:

```bash
cd /tmp/linkbit
sudo ./deploy/install-agent.sh
systemctl is-active linkbit-agent
journalctl -u linkbit-agent -n 30 --no-pager
```

## Rename by re-enrollment

There is no rename endpoint in the current controller. To rename `steven-remote` to `steven`, use this sequence:

1. Create a fresh invitation with admin key:

```bash
TOKEN=$(
  curl -fsS -H "X-Linkbit-API-Key: $ADMIN_KEY" \
    -H "Content-Type: application/json" \
    -d '{"userId":"default-user","groupId":"default","expiresInSeconds":86400}' \
    http://120.79.155.227/api/v1/invitations | jq -r '.token'
)
```

2. Stop remote agent and remove old local state:

```bash
sudo systemctl stop linkbit-agent
sudo rm -f /var/lib/linkbit/agent-state.json
```

3. Delete old controller policy and device:

```bash
curl -fsS -X DELETE -H "X-Linkbit-API-Key: $ADMIN_KEY" \
  http://120.79.155.227/api/v1/policies/local-to-steven-remote-ssh
curl -fsS -X DELETE -H "X-Linkbit-API-Key: $ADMIN_KEY" \
  http://120.79.155.227/api/v1/devices/<old-device-id>
```

4. Update remote env:

```bash
sudo sed -i \
  "s/^LINKBIT_ENROLLMENT_KEY=.*/LINKBIT_ENROLLMENT_KEY=$TOKEN/; s/^LINKBIT_DEVICE_NAME=.*/LINKBIT_DEVICE_NAME=steven/" \
  /etc/linkbit/agent.env
sudo systemctl restart linkbit-agent
```

5. Verify device list includes `steven`.

## Policy and local forward

Create policy from the local workstation device to the remote `steven` device:

```bash
curl -fsS -H "X-Linkbit-API-Key: $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id":"local-to-steven-ssh",
    "name":"Local to steven SSH",
    "sourceId":"<local-device-id>",
    "targetId":"<steven-device-id>",
    "ports":["22"],
    "protocol":"tcp",
    "enabled":true
  }' \
  http://120.79.155.227/api/v1/policies
```

Local systemd forward service:

```ini
[Unit]
Description=Linkbit SSH forward to steven
After=network-online.target linkbit-agent.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/linkbit-agent forward --controller http://120.79.155.227 --state /var/lib/linkbit/agent-state.json --listen 127.0.0.1:10023 --target steven:22
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Verify:

```bash
sshpass -p '1' ssh -p 10023 \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  steven@127.0.0.1 'hostname; echo renamed-forward-ok'
```

## 2026-08-13 addendum: fleet identities and the seeed-reserver install

### Identity map (avoid this confusion)

- ssh alias `seeed` (Tailscale 100.76.45.91) lands on `seeed-IdeaCentre-GeekPro-14IOB`, Ubuntu 22.04 — that box is the Linkbit device named **`seeed`** (10.88.222.222). It is NOT "the seeed0 machine". It was upgraded to 0.3.6 on 2026-08-13 (update BOTH `/usr/bin/linkbit-agent` via deb AND `/opt/linkbit/linkbit-agent` which the service runs; verify sha256 vs release `checksums.txt`).
- The real seeed0 machine is Linkbit device **`seeed-reserver`**: hostname `seeed0`, Ubuntu 24.04, reached at `seeed0@192.168.2.194` (also NIC 192.168.4.35), password `0`. Device id `94c3c811-b2fe-443c-b51d-813b30882657`, virtual IP `10.88.106.235`.

### seeed-reserver install (2026-08-13, agent 0.3.6)

- Fresh install: `dpkg -i linkbit-agent_0.3.6_linux_amd64.deb` (only /usr/bin binaries, no unit), then run `deploy/install-agent.sh` with the raw binary staged at `./bin/linkbit-agent` — it installs `/opt/linkbit/linkbit-agent` and the hardened systemd unit.
- **No admin key needed to enroll**: `POST /api/v1/devices/register` falls back to session auth when no enrollment key is provided. Set `LINKBIT_SESSION_TOKEN=<valid user session token>` in `/etc/linkbit/agent.env` instead of `LINKBIT_ENROLLMENT_KEY`.
- Installed wireguard-tools; `LINKBIT_WG_DRY_RUN=false` brings up a real `linkbit0`.
- CLI login: the `steven` account password is unknown; carry over a valid workstation session token into `~/.config/linkbit/config.json`.
- Session token of user `steven` works as `Authorization: Bearer` for `GET /api/v1/devices`; policy listing still needs the admin key.

### Operational lessons

- Gotcha: `LINKBIT_HEALTH_SECONDS=300` makes a device flap online/offline because the controller offline threshold is shorter. Use `30`.
- Fleet-wide as of 2026-08-13: NO device completes a WireGuard handshake with the hub (even the healthy workstation shows `transfer: 0 B received`, no latest handshake, mesh ICMP 100% loss). Likely hub UDP/443 not reachable or hub WG not configured on the controller. The working transport everywhere is TCP relay: `linkping` reports `via relay`, `linkbit-agent forward` carries real SSH fine. Don't chase per-device WG config for this.
- Verified connectivity from seeed-reserver via relay: steven 220ms, aliyun-cloud 86ms, radxa-cubie-a7a 164ms, friendlywrt 261ms, seeed 121ms; orangepi and steven-ubuntu correctly reported offline. Relay SSH to steven:22 tested end-to-end.

### 2026-08-19 re-sweep (one week later)

- All Linkbit paths still healthy via relay (steven ~70ms, aliyun-cloud ~100ms, radxa ~115ms, seeed ~118ms, friendlywrt ~179ms); seeed-reserver had a transient controller-path timeout window (~12:45-12:55 local) that self-recovered.
- OS-level real logins through relay: `steven` (steven/1) OK; `seeed` device OK — **the GeekPro SSH user is `seeed` with password 0, NOT seeed0** (inventory was wrong; seeed0 belongs to the other box). Relay fidelity proven by matching host keys. GeekPro LAN IP: 192.168.2.113; its Tailscale path (100.76.45.91) was broken at kex that day.
- No-cred devices verified via SSH banner grab through relay: friendlywrt (dropbear), aliyun-cloud (OpenSSH_8.9p1), radxa-cubie-a7a (OpenSSH_8.4p1). Some sshd builds only emit the banner after the client writes a byte — send a newline before reading.
- Direct-LAN sweep from seeed-reserver (192.168.2.0/24): only 192.168.2.1 alive — it is the FriendlyWrt router (root/pi login OK), i.e. same box as Linkbit device friendlywrt. recamera-10/11/12/nom/200/201, jetson, rv1126b all powered off (port 22 closed).

