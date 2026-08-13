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

## 2026-08-13 addendum: seeed0 upgrade to v0.3.6

- Device: `seeed` mini PC (hostname seeed-IdeaCentre-GeekPro-14IOB), Ubuntu 22.04 amd64, virtual IP `10.88.222.222`. Unix user is now `seeed0` (renamed 2026-08-11, password `0`, aliases `seeed`/`seeed0-lan`).
- The systemd unit runs `/opt/linkbit/linkbit-agent`, but the deb installs to `/usr/bin/linkbit-agent`. Upgrade BOTH: `dpkg -i linkbit-agent_0.3.6_linux_amd64.deb` then `install -m755` the raw release binary over `/opt/linkbit/linkbit-agent` (back up the old one first). Verify with `sha256sum` against release `checksums.txt`.
- Upgrade keeps the state file; no re-enrollment needed.
- Gotcha: `LINKBIT_HEALTH_SECONDS=300` makes the device flap online/offline because the controller offline threshold is shorter. Use `30`.
- CLI login: the `steven` account password is unknown; carry over a valid workstation session token into `~/.config/linkbit/config.json` instead of `linkbit login`.
- CLI binaries (`linkbit`, `linkping`) ship in `linkbit_v0.3.6_linux_amd64.tar.gz`; install to `/usr/local/bin`.
- `linkping` from this device reports `via relay` (its env keeps `LINKBIT_WG_DRY_RUN=true`, no `linkbit0` interface). All online devices reachable; offline devices (`orangepi`, `steven-ubuntu`) correctly rejected. Relay SSH proven end-to-end: `linkbit-agent forward --listen 127.0.0.1:10024 --target steven:22` + `ssh -p 10024 steven@127.0.0.1`.
- Session token of user `steven` works as `Authorization: Bearer` for `GET /api/v1/devices`; policy listing still needs the admin key.

