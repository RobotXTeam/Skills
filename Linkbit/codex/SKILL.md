---
name: linkbit
description: Operate, diagnose, deploy, onboard, package, and release the Linkbit controller, relay, CLI, desktop client, and Linux agent. Use for Linkbit mesh connectivity, virtual IP, ping/trace/speed/SSH, WireGuard Hub, TCP relay, invitation enrollment, policies, remote Ubuntu devices, GitHub releases, or the Linkbit repository.
---

# Linkbit

Work toward verified connectivity, not build success alone. When credentials and device access are available, run SSH/SCP/sudo/API operations directly and verify the real source-to-target path.

## Current network model

- The current release line is `v0.3.4`.
- `LINKBIT_MESH_ALL_DEVICES=true` is the controller default. It exposes all other devices as peers and authorizes relay sessions without per-pair policies. Create policies only when this setting is false.
- WireGuard carries native virtual-IP traffic. A Hub peer advertises the whole `10.88.0.0/16`; agents then route the entire Linkbit network through that Hub.
- Agents refresh network config every 30 seconds by default. Configure `LINKBIT_NETWORK_SYNC_SECONDS` or `linkbit-agent --network-sync`.
- TCP Relay carries service traffic when UDP/WireGuard is unavailable. Linux transparent TCP can preserve `10.88.x.x:<port>` UX; target agents must log `tcp relay target enabled`.
- `linkbit ping <device>` first tries OS ICMP, then uses an authenticated Relay probe. Read the reported `via direct` or `via relay` field.
- Plain `ping 10.88.x.x` has no Relay fallback. It proves WireGuard only and requires bidirectional UDP reachability to the Hub or a reachable direct peer endpoint.

## Connectivity diagnosis

1. Check Controller and device control plane:
   `curl -fsS http://<controller>/healthz`, then inspect `/api/v1/devices/{id}/network-config` with device credentials.
2. Run `linkbit trace <device>`, `linkbit ping <device>`, and `linkbit speed <device>` from the enrolled source.
3. On the source, inspect `ip route`, `ip address show linkbit0`, and `wg show linkbit0`.
4. On the target, require an online Agent and `tcp relay target enabled` before testing Relay paths.
5. Test the actual service, such as SSH login or an RDP/NoMachine connection. A TCP accept alone can be a local transparent-proxy false positive.

Interpret results precisely:

- `linkbit ping ... via relay` plus a successful speed probe proves source credentials, Controller authorization, Relay streaming, and the target Agent.
- `wg show` with bytes sent but `0 B received`, including failure to ping the Hub IP, means the WireGuard endpoint is not returning UDP. Check Hub process/listen socket, cloud UDP security rules, endpoint/port, and server firewall forwarding.
- Peers with empty endpoints cannot form direct WireGuard sessions. They need the Hub path.
- Do not call a Relay ping success proof that plain ICMP works. Do not call a WireGuard failure a Mesh authorization failure when Relay succeeds.

Read [references/2026-07-11-v0.3.4-mesh-ping.md](./references/2026-07-11-v0.3.4-mesh-ping.md) for the v0.3.3 failure evidence and v0.3.4 fix.

## Ubuntu onboarding

1. Build: `.tools/go/bin/go build -o bin/linkbit-agent ./cmd/linkbit-agent`.
2. Validate Controller invitation creation before touching the remote host.
3. Prefer the agent-only deb, or use `scripts/remote-ubuntu-agent-install.sh`.
4. Keep reusable remote files under `~/.steven/Linkbit`.
5. Verify registration, online status, Relay target log, authorization mode, `linkbit ping`, and a real service path.

Enrollment tokens are bootstrap-only. Reconnect uses the device ID/token in the state file. There is no rename API; rename by removing local state and the old Controller device, then enroll with a fresh token and desired name.

For flaky management SSH, use a reachable jump host with `ProxyCommand`. For flaky Tailscale transfer paths, prefer remote `curl -C -` release downloads over a large initial `scp`. Check Clash/Mihomo TUN interception if Tailscale appears online but stalls at SSH banner.

## Release workflow

When asked to publish, complete the whole release: inspect changes, test, commit, push `main`, tag, build/upload assets, and verify GitHub state. Do not stop at instructions when credentials are available.

Never put a GitHub PAT in the repository, skill, remote URL, or committed files. Use a transient `GITHUB_TOKEN`. On Steven's workstation, read it from `~/.config/linkbit/github_token` only when the environment variable is absent. The known working account is `Nova-Steven` with push access to `RobotXTeam/Linkbit`; use an HTTP Basic extraheader if normal token URL auth fails:

```sh
GITHUB_TOKEN="${GITHUB_TOKEN:-$(cat ~/.config/linkbit/github_token)}"
AUTH=$(printf 'Nova-Steven:%s' "$GITHUB_TOKEN" | base64 -w0)
git -c http.https://github.com/.extraheader="AUTHORIZATION: basic $AUTH" \
  push https://github.com/RobotXTeam/Linkbit.git main:main
```

Release sequence:

1. Inspect `git status --short --branch` and diffs; preserve unrelated user changes.
2. Run `GOROOT=$PWD/.tools/go ./.tools/go/bin/go test ./...`.
3. Commit and push `main`.
4. Select the next semantic version and build with `LINKBIT_VERSION=vX.Y.Z ./scripts/package-release.sh`.
5. Confirm CLI archives, Linux agent deb/rpm, desktop assets, and `checksums.txt`.
6. Create and push annotated tag `vX.Y.Z`. The tag triggers `.github/workflows/release.yml`.
7. Verify remote main/tag SHA, Actions jobs, GitHub Release metadata, asset list, and checksums. Upload locally verified assets through the GitHub API when needed.

## Repository invariants

- `scripts/remote-install.sh` deploys Controller/Relay, not endpoint agents.
- Keep TCP Relay startup independent from WireGuard success.
- `LINKBIT_WG_DRY_RUN=true` deliberately disables native WireGuard traffic; Relay can still work.
- Remote desktop requires a real target RDP/VNC/NoMachine/RustDesk service.
- Transparent TCP is Linux-specific; keep syscall code behind Linux build tags and retain a non-Linux stub.
- Do not restore obsolete desktop controls unless current product requirements explicitly change.

## References

- Ownership map: [references/repo-scan.md](./references/repo-scan.md)
- Ubuntu onboarding: [references/ubuntu-cli-playbook.md](./references/ubuntu-cli-playbook.md)
- Direct-IP Relay history: [references/2026-05-10-direct-ip-transparent-relay.md](./references/2026-05-10-direct-ip-transparent-relay.md)
- Known devices: [references/seeed-device.md](./references/seeed-device.md) and [references/steven-device-2026-04-29.md](./references/steven-device-2026-04-29.md)
- Installer helper: [scripts/remote-ubuntu-agent-install.sh](./scripts/remote-ubuntu-agent-install.sh)
