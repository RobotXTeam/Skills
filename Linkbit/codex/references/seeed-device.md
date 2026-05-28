# Seeed Device Notes

Use this for onboarding `seeed@100.76.45.91` as a Linkbit device named `seeed`.

## Access

- SSH: `seeed@100.76.45.91`
- Password: supplied by user in chat
- Reliable two-hop SSH when direct Tailscale SSH is flaky:
  local `ssh -p 10023 steven@127.0.0.1`, then `ssh seeed@192.168.3.153`
- Hostname observed: `seeed-IdeaCentre-GeekPro-14IOB`
- OS: Ubuntu 22.04 lineage with kernel `6.8.0-107-generic`

This host can show as Tailscale `active` while `tailscale ping` and SSH data paths still time out. Retry 22/tcp before declaring the host offline.

## Workspace

Keep Linkbit files under:

```text
/home/seeed/.steven/Linkbit
```

Suggested layout:

```text
~/.steven/Linkbit/
  bin/
  deploy/
  release/
  logs/
```

## Preferred Install Method

For this host, avoid large local `scp` unless the link is clearly stable. Prefer remote self-download with resume:

```bash
mkdir -p ~/.steven/Linkbit/release
curl -L --fail --connect-timeout 15 --max-time 600 -C - \
  -o ~/.steven/Linkbit/release/linkbit.tar.gz \
  https://github.com/RobotXTeam/Linkbit/releases/download/v0.2.0/linkbit_v0.2.0_linux_amd64.tar.gz
tar -xzf ~/.steven/Linkbit/release/linkbit.tar.gz -C ~/.steven/Linkbit/release
```

Then install from:

```text
~/.steven/Linkbit/release/linkbit/
```

Important 2026-04-30 finding: the GitHub release `v0.2.0` agent registered the device, but on this host it did not reach `tcp relay target enabled`. It hung after loading state / WireGuard setup. The working fix was to overwrite `/opt/linkbit/linkbit-agent` with the current locally built `bin/linkbit-agent`, keep `LINKBIT_WG_DRY_RUN=true`, and restart `linkbit-agent`.

Write `/etc/linkbit/agent.env` with:

```env
LINKBIT_CONTROLLER_URL=http://120.79.155.227
LINKBIT_ENROLLMENT_KEY=<fresh-token>
LINKBIT_DEVICE_NAME=seeed
LINKBIT_HEALTH_SECONDS=300
LINKBIT_WG_INTERFACE=linkbit0
LINKBIT_WG_DRY_RUN=true
LINKBIT_STATE_PATH=/var/lib/linkbit/agent-state.json
LINKBIT_TCP_RELAY_ENABLED=true
LINKBIT_RUN_ONCE=false
```

Install:

```bash
cd ~/.steven/Linkbit/release/linkbit
sudo ./deploy/install-agent.sh
```

If the service starts but local forwarding times out during SSH banner exchange, check for this log line on the Seeed host:

```text
tcp relay target enabled
```

If absent, upload the current local agent through the two-hop path and restart:

```bash
sshpass -p '0' scp \
  -o ProxyCommand="sshpass -p '1' ssh -p 10023 steven@127.0.0.1 nc %h %p" \
  bin/linkbit-agent seeed@192.168.3.153:/home/seeed/.steven/Linkbit/bin/linkbit-agent-current

sshpass -p '0' ssh \
  -o ProxyCommand="sshpass -p '1' ssh -p 10023 steven@127.0.0.1 nc %h %p" \
  seeed@192.168.3.153 \
  'echo 0 | sudo -S -p "" install -m 0755 ~/.steven/Linkbit/bin/linkbit-agent-current /opt/linkbit/linkbit-agent && echo 0 | sudo -S -p "" systemctl restart linkbit-agent'
```

Verify:

```bash
systemctl is-active linkbit-agent
journalctl -u linkbit-agent -n 30 --no-pager
curl -fsS -H "X-Linkbit-API-Key: $ADMIN_KEY" http://120.79.155.227/api/v1/devices | jq -r '.[] | [.name,.virtualIp,.status] | @tsv'
```

Final verified state:

- Device name: `seeed`
- Virtual IP: `10.88.222.222`
- Remote service: `linkbit-agent.service` active
- Remote workspace: `/home/seeed/.steven/Linkbit`
- Local forward service: `linkbit-forward-seeed-ssh.service`
- Local SSH entry: `ssh -p 10024 seeed@127.0.0.1`
- Verified command returned: `seeed-linkbit-forward-ok`

## Failure Modes

- `scp` hangs: kill local `scp/sshpass` and remote `scp -t <file>` processes, then switch to remote `curl -C -`.
- `curl` timeout mid-download: rerun the exact `curl -C -` command to resume.
- SSH banner timeout: wait and retry `nc -vz -w 5 100.76.45.91 22`; do not assume password failure.
