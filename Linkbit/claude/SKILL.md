---
name: Linkbit
description: Use this skill when working in the Linkbit repo for controller/relay/agent deployment, Ubuntu remote-agent onboarding, device invitation enrollment, policy setup, and TCP relay forwarding for SSH or desktop protocols.
---

# Linkbit Skill

Use this skill for operational work in the Linkbit codebase, especially when the goal is to get real connectivity working (not just build success).

## When to use

- User asks how to deploy or operate Linkbit controller/relay/agent.
- User asks how to enroll remote Ubuntu devices through CLI.
- User asks how to set up SSH/RDP/NoMachine forwarding through Linkbit.
- User asks to connect through a jump host or recover a slow/direct SSH path.
- User asks to package or install headless CLI/agent on devices without a desktop.
- User asks where to edit or debug APIs, policies, invitations, or relay sessions.

## Fast path

1. Build Linux binaries:
   `./scripts/build-linux-amd64.sh`
2. Confirm controller health:
   `curl -fsS http://<controller>/healthz`
3. Create invitation token with admin key:
   `POST /api/v1/invitations`
4. Install `linkbit-agent` on remote Ubuntu and write `/etc/linkbit/agent.env`.
5. Ensure policy allows source device -> target device.
6. Start local forward:
   `linkbit-agent forward --listen 127.0.0.1:10022 --target <device-name>:22`

## Key truths in this repo

- `scripts/remote-install.sh` uploads controller/relay artifacts only; it is not a remote agent installer.
- Enrollment token is one-time bootstrap for first registration; reconnect uses state file device credentials.
- TCP relay forwarding requires policy authorization (`sourceId` -> `targetId`, protocol `tcp`).
- Remote desktop still requires the target service to exist (RDP/VNC/NoMachine/SSH); Linkbit only provides transport.
- There is no device rename API today. To rename a registered agent, stop the agent, remove its local state, delete the old controller device/policy, and re-enroll with a fresh token and the desired `LINKBIT_DEVICE_NAME`.
- If direct SSH to a target is unstable, use a `ProxyCommand` through the reachable jump host and keep using the same installation flow.
- For headless Ubuntu/Debian, prefer the agent-only deb package made by `./scripts/package-agent-deb.sh` when available.

## Primary references

- Repo scan and ownership map: [references/repo-scan.md](./references/repo-scan.md)
- Ubuntu remote onboarding and forwarding playbook: [references/ubuntu-cli-playbook.md](./references/ubuntu-cli-playbook.md)
- Real 2026-04-29 steven device runbook: [references/steven-device-2026-04-29.md](./references/steven-device-2026-04-29.md)
- End-to-end helper script: [scripts/remote-ubuntu-agent-install.sh](./scripts/remote-ubuntu-agent-install.sh)

## Execution checklist

1. Validate controller API key and invitation flow first.
2. Install remote agent as systemd service on Ubuntu.
3. Verify remote agent online status in `/api/v1/devices`.
4. Verify or create network policy for the intended source-target pair.
5. Start local forward and test with real client (`ssh`, `mstsc`, NoMachine client, etc).
