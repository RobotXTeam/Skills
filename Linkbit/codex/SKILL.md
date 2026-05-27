---
name: Linkbit
description: Use this skill when working in the Linkbit repo for controller/relay/agent deployment, Ubuntu remote-agent onboarding, device invitation enrollment, policy setup, and TCP relay forwarding for SSH or desktop protocols.
---

# Linkbit Skill

Use this skill for operational work in the Linkbit codebase, especially when the goal is to get real connectivity working (not just build success).

Default execution stance: Codex should perform the work directly when SSH credentials or local access are available. Do not turn Linkbit onboarding into "give the user commands to copy"; use SSH/SCP/sudo/API calls yourself, then verify the real device and forwarding path.

## When to use

- User asks how to deploy or operate Linkbit controller/relay/agent.
- User asks how to enroll remote Ubuntu devices through CLI.
- User asks how to set up SSH/RDP/NoMachine forwarding through Linkbit.
- User asks to connect through a jump host or recover a slow/direct SSH path.
- User asks to package or install headless CLI/agent on devices without a desktop.
- User asks where to edit or debug APIs, policies, invitations, or relay sessions.
- User asks to push Linkbit changes to the cloud, update GitHub, publish a tag, or refresh release assets.

## Fast path

1. Build Linux binaries:
   `.tools/go/bin/go build -o bin/linkbit-agent ./cmd/linkbit-agent`
2. Confirm controller health:
   `curl -fsS http://<controller>/healthz`
3. Create invitation token with admin key:
   `POST /api/v1/invitations`
4. Install `linkbit-agent` on remote Ubuntu with TCP relay as the default path:
   `scripts/remote-ubuntu-agent-install.sh`
5. Ensure policy allows source device -> target device for `22,3389,4000`.
6. Test direct Linkbit IP:
   `ssh <user>@10.88.x.x` or connect to `10.88.x.x:3389` / `10.88.x.x:4000`.

## Cloud push and release path

When the user invokes this skill and asks to push new Linkbit changes to the cloud, default to doing the full GitHub update directly: verify, commit, push `main`, tag, build release artifacts, create/update the GitHub release, upload assets, and verify the remote state. Do not stop at instructions unless credentials are unavailable.

Never write a GitHub PAT into this skill, the repo, shell history, or committed files. On Steven's workstation, default to reading the GitHub PAT from `~/.config/linkbit/github_token` when `GITHUB_TOKEN` is not already set. Use a transient environment variable such as `GITHUB_TOKEN` or `TOKEN` for the current shell command only. The working GitHub account for the previous successful run was `Nova-Steven`, with collaborator push permission on `RobotXTeam/Linkbit`. Classic PATs with `repo` and `workflow` scopes worked through the GitHub API. For Git push, the reliable method was an HTTP Basic extraheader, not embedding the token in the remote URL:

```sh
GITHUB_TOKEN="${GITHUB_TOKEN:-$(cat ~/.config/linkbit/github_token)}"
AUTH=$(printf 'Nova-Steven:%s' "$GITHUB_TOKEN" | base64 -w0)
git -c http.https://github.com/.extraheader="AUTHORIZATION: basic $AUTH" \
  push https://github.com/RobotXTeam/Linkbit.git main:main
```

Recommended end-to-end sequence:

1. Check workspace state with `git status --short --branch`, inspect diffs, and avoid reverting unrelated user changes.
2. Run tests before release:
   `GOROOT=$PWD/.tools/go ./.tools/go/bin/go test ./...`
3. Commit current changes with a focused message.
4. Push `main` using the `http.extraheader` pattern above.
5. Pick the next semver tag from `git tag --list --sort=-version:refname`; for normal release bumps, use the next patch version.
6. Build local release assets:
   `LINKBIT_VERSION=vX.Y.Z ./scripts/package-release.sh`
7. Confirm `artifacts/release/` contains `checksums.txt`, Linux amd64/arm64 tarballs, Darwin amd64/arm64 tarballs, Windows amd64 zip, and the Linux desktop AppImage when desktop build is enabled.
8. Create and push an annotated tag:
   `git tag -a vX.Y.Z -m "Linkbit vX.Y.Z"`
   then push the tag with the same `http.extraheader` auth pattern.
9. Create the GitHub release via API if the Actions release is not enough or you need to upload locally verified artifacts:
   `POST https://api.github.com/repos/RobotXTeam/Linkbit/releases`
10. Upload assets to the release upload URL with `curl --data-binary @artifact`.
11. Verify the release asset list, remote `main` SHA, pushed tag, and local `git status --short --branch`.

Known release lessons:

- If `git push https://x-access-token:$TOKEN@github.com/...` returns `Invalid username or token` while the GitHub API shows `permissions.push: true`, retry using the `http.extraheader` Basic Auth pattern above.
- `./scripts/package-release.sh` should select the newest `desktop/dist/*.AppImage`; stale AppImages in `desktop/dist` previously caused `cp ... target is not a directory`.
- Transparent TCP is Linux-specific. Keep Linux syscall code behind a `//go:build linux` file and provide a non-Linux stub so cross-platform release builds keep working.
- A tag push triggers `.github/workflows/release.yml`; still verify Actions status and release assets explicitly. If needed, create or update the release directly through the GitHub API and upload the locally built artifacts.

## Key truths in this repo

- `scripts/remote-install.sh` uploads controller/relay artifacts only; it is not a remote agent installer.
- Enrollment token is one-time bootstrap for first registration; reconnect uses state file device credentials.
- TCP relay forwarding requires policy authorization (`sourceId` -> `targetId`, protocol `tcp`).
- Current product path is direct Linkbit IP with transparent TCP relay fallback, not user-managed local listen ports. Users should connect to `10.88.x.x:<service-port>` directly.
- Do not reintroduce the old desktop UI fields `本地监听`, `远端目标`, `启动 SSH/RDP 中转`, or `停止中转`.
- Agent startup must not let WireGuard failure prevent TCP relay. The expected default for remote target devices is `LINKBIT_WG_DRY_RUN=true`, `LINKBIT_TCP_RELAY_ENABLED=true`, and `LINKBIT_TRANSPARENT_TCP=false`; the local workstation may use `LINKBIT_TRANSPARENT_TCP=true`.
- Remote desktop still requires the target service to exist (RDP/VNC/NoMachine/SSH); Linkbit only provides transport.
- There is no device rename API today. To rename a registered agent, stop the agent, remove its local state, delete the old controller device/policy, and re-enroll with a fresh token and the desired `LINKBIT_DEVICE_NAME`.
- If direct SSH to a target is unstable, use a `ProxyCommand` through the reachable jump host and keep using the same installation flow.
- For headless Ubuntu/Debian, prefer the agent-only deb package made by `./scripts/package-agent-deb.sh` when available.
- Put temporary remote Linkbit install files under `~/.steven/Linkbit` when the user wants a tidy per-user workspace. Avoid scattering new Linkbit files in `/tmp` except for short-lived probes.
- For flaky Tailscale SSH, avoid large `scp` first. Prefer remote self-download from GitHub release with `curl -C -` resume, or stream a compressed tar only after confirming the SSH data path is stable.
- If a remote device registers but SSH forwarding times out during banner exchange, verify the target agent log contains `tcp relay target enabled`. If not, set `LINKBIT_WG_DRY_RUN=true` and use the current locally built agent binary before retesting TCP relay.
- A plain TCP connect to `10.88.x.x` can be misleading because the local transparent proxy may accept the socket first. Treat SSH banner/login or target agent logs as the real proof.
- If Tailscale management paths look connected but hang at SSH banner, check whether Clash Verge/Mihomo TUN (`Meta`, fake IP `198.18.0.0/16`, table `2022`) is intercepting `100.64.0.0/10` or `controlplane.tailscale.com`. Stop Clash TUN only as a temporary repair path and restart it afterward.

## Primary references

- Repo scan and ownership map: [references/repo-scan.md](./references/repo-scan.md)
- Ubuntu remote onboarding and forwarding playbook: [references/ubuntu-cli-playbook.md](./references/ubuntu-cli-playbook.md)
- Real 2026-04-29 steven device runbook: [references/steven-device-2026-04-29.md](./references/steven-device-2026-04-29.md)
- Seeed device onboarding notes: [references/seeed-device.md](./references/seeed-device.md)
- Direct-IP transparent relay worklog: [references/2026-05-10-direct-ip-transparent-relay.md](./references/2026-05-10-direct-ip-transparent-relay.md)
- End-to-end helper script: [scripts/remote-ubuntu-agent-install.sh](./scripts/remote-ubuntu-agent-install.sh)

## Execution checklist

1. Validate controller API key and invitation flow first.
2. Install remote agent as systemd service on Ubuntu.
3. Verify remote agent online status in `/api/v1/devices`.
4. Verify or create network policy for the intended source-target pair.
5. Test direct Linkbit IP with real client (`ssh`, `mstsc`, NoMachine client, etc).
6. For new devices, do not call the job finished until the target agent log contains `tcp relay target enabled`, controller policy exists, and a source-side direct IP test succeeds.
