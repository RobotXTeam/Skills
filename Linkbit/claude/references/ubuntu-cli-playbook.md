# Ubuntu CLI Playbook

This playbook is for installing Linkbit agent on a remote Ubuntu device, enrolling it via invitation token, and forwarding SSH or desktop ports through Linkbit relay.

## Preconditions

- Controller is reachable (example: `http://120.79.155.227`).
- You have admin API key (`X-Linkbit-API-Key`).
- Local machine has built `bin/linkbit-agent`.
- Remote Ubuntu has `sudo` access.

## 1. Build binary

```bash
./scripts/build-linux-amd64.sh
```

## 2. Create invitation token

```bash
export CONTROLLER_URL=http://120.79.155.227
export ADMIN_KEY='replace-with-admin-key'

TOKEN=$(
  curl -sS "$CONTROLLER_URL/api/v1/invitations" \
    -H "X-Linkbit-API-Key: $ADMIN_KEY" \
    -H "Content-Type: application/json" \
    -d '{"userId":"default-user","groupId":"default","expiresInSeconds":86400}' \
  | jq -r '.token'
)
```

## 3. Upload and install on remote Ubuntu

```bash
export REMOTE=ubuntu@203.0.113.10
export DEVICE_NAME=ubuntu-remote

ssh "$REMOTE" 'mkdir -p /tmp/linkbit/bin /tmp/linkbit/deploy'
scp bin/linkbit-agent "$REMOTE:/tmp/linkbit/bin/"
scp deploy/install-agent.sh "$REMOTE:/tmp/linkbit/deploy/"

ssh "$REMOTE" 'sudo apt-get update && sudo apt-get install -y wireguard-tools iproute2 ca-certificates openssh-server'

ssh "$REMOTE" "sudo mkdir -p /etc/linkbit && sudo tee /etc/linkbit/agent.env >/dev/null" <<EOF
LINKBIT_CONTROLLER_URL=$CONTROLLER_URL
LINKBIT_ENROLLMENT_KEY=$TOKEN
LINKBIT_DEVICE_NAME=$DEVICE_NAME
LINKBIT_HEALTH_SECONDS=30
LINKBIT_WG_INTERFACE=linkbit0
LINKBIT_WG_DRY_RUN=false
LINKBIT_STATE_PATH=/var/lib/linkbit/agent-state.json
LINKBIT_TCP_RELAY_ENABLED=true
LINKBIT_RUN_ONCE=false
EOF

ssh "$REMOTE" 'cd /tmp/linkbit && sudo ./deploy/install-agent.sh'
```

## 4. Verify remote online status

```bash
ssh "$REMOTE" 'systemctl status linkbit-agent --no-pager'

curl -sS "$CONTROLLER_URL/api/v1/devices" \
  -H "X-Linkbit-API-Key: $ADMIN_KEY" | jq
```

## 5. Ensure policy exists

Without policy, relay session creation can be rejected as forbidden.

```bash
curl -sS "$CONTROLLER_URL/api/v1/policies" \
  -H "X-Linkbit-API-Key: $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id":"allow-workstation-to-ubuntu-remote",
    "name":"Allow workstation -> ubuntu-remote",
    "sourceId":"default",
    "targetId":"default",
    "protocol":"tcp",
    "ports":["*"],
    "enabled":true
  }'
```

## 6. Start local forwarding

SSH forwarding:

```bash
linkbit-agent forward \
  --controller "$CONTROLLER_URL" \
  --state ~/.config/linkbit/agent-state.json \
  --listen 127.0.0.1:10022 \
  --target ubuntu-remote:22

ssh -p 10022 ubuntu@127.0.0.1
```

Desktop forwarding examples:

- RDP: `--listen 127.0.0.1:13389 --target ubuntu-remote:3389`
- VNC: `--listen 127.0.0.1:15900 --target ubuntu-remote:5900`
- NoMachine: `--listen 127.0.0.1:14000 --target ubuntu-remote:4000`

## Troubleshooting

- `enrollment key is required for first registration`:
  state file missing and `LINKBIT_ENROLLMENT_KEY` absent.
- `network policy does not allow this target`:
  source->target policy missing or disabled.
- `target device not found`:
  forwarding target name/ID/virtualIP does not match registered device.
- `address already in use`:
  local listen port occupied; switch to a new local port.

