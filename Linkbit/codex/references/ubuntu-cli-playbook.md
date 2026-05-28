# Ubuntu CLI Playbook

This playbook is for installing Linkbit agent on a remote Ubuntu device, enrolling it via invitation token, and forwarding SSH or desktop ports through Linkbit relay.

Codex should execute this flow directly when the user supplies SSH credentials. The expected output is a verified online device and a working forward, not a list of commands for the user to paste.

## Preconditions

- Controller is reachable (example: `http://120.79.155.227`).
- You have admin API key (`X-Linkbit-API-Key`).
- Local machine has built `bin/linkbit-agent`.
- Remote Ubuntu has `sudo` access.
- Use `~/.steven/Linkbit` as the remote working directory when the user wants Linkbit files gathered under their private workspace.

## 1. Build binary

```bash
./scripts/build-linux-amd64.sh
```

For headless Ubuntu/Debian devices, prefer the agent-only deb when available:

```bash
./scripts/package-agent-deb.sh
sudo apt install ./artifacts/release/linkbit-agent_<version>_linux_amd64.deb
sudo linkbit-agent-configure \
  --controller http://120.79.155.227 \
  --enrollment-key <token> \
  --name <device-name> \
  --health-seconds 300
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
export REMOTE_WORKDIR=~/.steven/Linkbit

ssh "$REMOTE" "mkdir -p $REMOTE_WORKDIR/bin $REMOTE_WORKDIR/deploy"
scp bin/linkbit-agent "$REMOTE:$REMOTE_WORKDIR/bin/"
scp deploy/install-agent.sh "$REMOTE:$REMOTE_WORKDIR/deploy/"

ssh "$REMOTE" 'sudo apt-get update && sudo apt-get install -y wireguard-tools iproute2 ca-certificates openssh-server'

ssh "$REMOTE" "sudo mkdir -p /etc/linkbit && sudo tee /etc/linkbit/agent.env >/dev/null" <<EOF
LINKBIT_CONTROLLER_URL=$CONTROLLER_URL
LINKBIT_ENROLLMENT_KEY=$TOKEN
LINKBIT_DEVICE_NAME=$DEVICE_NAME
LINKBIT_HEALTH_SECONDS=300
LINKBIT_WG_INTERFACE=linkbit0
LINKBIT_WG_DRY_RUN=true
LINKBIT_STATE_PATH=/var/lib/linkbit/agent-state.json
LINKBIT_TCP_RELAY_ENABLED=true
LINKBIT_TRANSPARENT_TCP=false
LINKBIT_RUN_ONCE=false
EOF

ssh "$REMOTE" "cd $REMOTE_WORKDIR && sudo ./deploy/install-agent.sh"
```

Use `LINKBIT_HEALTH_SECONDS=300` for a 5-minute remote health report interval. This is separate from TCP relay target polling, which should stay fast so inbound relay connections wake promptly.

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
- `text file busy` when running the uploaded agent:
  a stale remote `scp -t <path>` process may still hold the binary open. Kill that remote `scp` process, then rerun the binary.

## Jump-host pattern

When direct SSH to the remote Ubuntu is unreliable but a jump host is available, keep the same install flow and wrap SSH/SCP with `ProxyCommand`.

Example from the 2026-04-29 successful run:

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

## Flaky SSH / Slow Upload Pattern

For hosts that intermittently time out during `scp`, make the remote host download the release itself and resume partial transfers:

```bash
ssh "$REMOTE" 'mkdir -p ~/.steven/Linkbit/release'
ssh "$REMOTE" 'curl -L --fail --connect-timeout 15 --max-time 600 -C - \
  -o ~/.steven/Linkbit/release/linkbit.tar.gz \
  https://github.com/RobotXTeam/Linkbit/releases/download/v0.2.0/linkbit_v0.2.0_linux_amd64.tar.gz'
ssh "$REMOTE" 'tar -xzf ~/.steven/Linkbit/release/linkbit.tar.gz -C ~/.steven/Linkbit/release'
```

If a transfer gets stuck, check and kill stale remote `scp -t ...` or `curl` processes before retrying.
