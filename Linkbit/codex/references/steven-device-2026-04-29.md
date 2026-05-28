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
LINKBIT_WG_DRY_RUN=true
LINKBIT_STATE_PATH=/var/lib/linkbit/agent-state.json
LINKBIT_TCP_RELAY_ENABLED=true
LINKBIT_TRANSPARENT_TCP=false
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
