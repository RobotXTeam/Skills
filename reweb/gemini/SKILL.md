---
name: reweb
description: Develop the sscma-example-sg200x reCamera Supervisor frontend and backend against Steven's live reCamera through OpenWrt, including script-driven Vite preview (`npm run dev -- --host 0.0.0.0`; the repo's `.claude/launch.json` carries the reference entry), API/WebSocket tunnels, cross-compilation, backed-up device deployment, verification, and rollback. Use when continuing this reCamera Studio UI project, modifying Supervisor/Node-RED integration, deploying to 192.168.2.102, or asking for real-time reCamera full-stack development.
---

# reCamera Live Full-Stack Development

Use this skill for the ongoing reCamera Studio in `/home/steven/sscma-example-sg200x`. It complements the `recamera` Wiki QA/NPU-demo skill; it does not replace it.

## Fixed project topology

- Repository: `/home/steven/sscma-example-sg200x`
- Frontend: `solutions/supervisor/www` (React 18, TypeScript, Vite)
- Backend: `solutions/supervisor/main` plus `rootfs/usr/share/supervisor/scripts/main.sh`
- Device: `192.168.2.102`, reached through OpenWrt
- OpenWrt SSH target: `root@10.88.92.200` by default; override with `OPENWRT_SSH_TARGET`
- Local forwards:
  - `127.0.0.1:18080` -> device `:80` (Supervisor HTTP)
  - `127.0.0.1:18081` -> device `:1880` (Node-RED HTTP/WS)
  - `127.0.0.1:18082` -> device `:9090` (ttyd WS)
  - `127.0.0.1:18083` -> device `:8001` (debug/video WS)
- Vite preview: `http://127.0.0.1:5173`

Read [architecture.md](references/architecture.md) before changing routing, proxying, WebSockets, or backend ownership. Read [device-layout.md](references/device-layout.md) before any device operation.

## Credentials

Never put a password in this skill, the repository, shell history, or generated config.

Prefer SSH keys/agent for OpenWrt. The device wrappers accept `RECAMERA_PASSWORD` only as a process environment variable when key authentication is unavailable. Privileged deploys accept `RECAMERA_SUDO_PASSWORD` as an environment variable. Do not print either variable.

## Invocation behavior

When invoked with `/reweb` and a request such as `继续开发 reCamera web，启动隧道和本地预览`, act immediately without asking setup questions:

1. Run the read-only preflight.
2. Start or reuse all four OpenWrt tunnels.
3. Start or reuse your browser tool against the Vite dev server at `http://127.0.0.1:5173` (launch config `supervisor-webui` from `.claude/launch.json`; `npm run dev -- --host 0.0.0.0` with cwd `solutions/supervisor/www`).
4. Reload the page and verify real device content, current network failures, and connection state.
5. Leave the preview open for continued development.

After completing and verifying a reCamera Supervisor Web change, deploy the finished change to the live device by default. Do not wait for a separate deployment request. This standing authorization covers routine frontend, Supervisor backend, and narrowly required runtime-file deployment through the backed-up `reweb` workflow. It does not authorize firmware flashing, device reboot, destructive operations, run-mode changes, network reconfiguration, or unrelated device writes; those still require an explicit request.

## Standard workflow

1. Inspect `git status` and preserve all existing changes. Never reset or overwrite unrelated work.
2. Run local and read-only checks:
   ```bash
   /home/steven/.gemini/skills/reweb/scripts/preflight.sh
   ```
3. Start tunnels if they are not already listening:
   ```bash
   /home/steven/.gemini/skills/reweb/scripts/start-tunnels.sh
   ```
4. Start the frontend dev server in the background: `npm run dev -- --host 0.0.0.0` with cwd `solutions/supervisor/www`, then verify with your browser tool (`http://127.0.0.1:5173`).
5. Modify the narrowest relevant layer. Use `src/utils/deviceProxy.ts` for service URLs and existing request helpers for API calls.
6. Run the frontend production build and `git diff --check`.
7. Verify through your browser tool against real device data: console, server log, network, snapshot, interactions, responsive layout, then screenshot.
8. Deploy the verified completed change to the live device by default. Run a fresh read-only preflight and deployment dry-run, identify the exact files, preserve mode/service state, create a timestamped backup, stage under `/tmp`, keep rollback active, and verify the real device boundary after replacement.
9. Leave the device in a healthy final state and report the backup path, verification results, and exact rollback command.

Detailed commands are in [development-workflow.md](references/development-workflow.md).

## Browser tool usage

Use a browser tool only when visual or interactive verification is necessary.

Prefer a plain local load or shell checks for state questions; avoid screenshots unless required.

Do not retain or repeatedly inspect full-page screenshots.

Use DOM/text inspection where possible.

## Live preview layout rules (must not regress)

The `#/live` preview must scale continuously with the available content width and must never enlarge/recenter when a tab or overlay changes. The layout lives in `solutions/supervisor/www/src/views/live/index.css`; the player is `.video-wrapper` with `aspect-ratio: 16 / 9`. Follow these rules when touching it:

- Keep the browser tool at its **native/adaptive desktop size**. Never leave it pinned to a fixed mobile, tablet, or custom viewport between sessions — a stale fixed viewport is the usual reason the preview "looks wrong" on a new `/reweb` session. Resize to native/desktop before measuring.
- Layout columns use a **flexible ratio** (`minmax(0, 3fr) minmax(340px, 2fr)`), not a fixed-width sidebar. The player and settings panel both flex with content width.
- Responsive collapse uses a **container query** on `.live-page-container` (`container-type: inline-size` + `@container (max-width: 620px)`), NOT a `@media (max-width: 1200px)` viewport query. A viewport query couples layout to the browser window, so the sidebar's width flips the layout at the wrong time and the player jumps to full-width centered. The container query couples it to the actual content area.
- The collapse breakpoint is **620px of content width** — narrow enough that a normal desktop with the sidebar never collapses prematurely. If you raise it back toward 900–1200px you will reintroduce the "preview suddenly enlarges and centers" bug.
- A tab change (Display ↔ AI/Annotate) or an overlay toggle must never resize the player. `OverlayCanvas` and the overlay DOM are positioned absolutely over `.video-wrapper`; they must not add layout or push the wrapper. If a tab change changes `.video-wrapper`'s width or height, treat it as a regression.
- The video element is `object-fit: contain` inside `.video-wrapper`; the wrapper's `aspect-ratio` is the single source of player size. Do not set a fixed width or height on the video element.

Verification when changing `#/live` layout (run after every edit):

1. Build: `npm --prefix solutions/supervisor/www run build` and `git diff --check`.
2. At native desktop width: measure `.live-page-content`, `.live-player-section`, `.video-wrapper`, `.live-settings-section`. Confirm two-column layout and player ≈ 16:9.
3. Resize the browser tool viewport down to ~1040px and ~900px. Confirm the player scales continuously and only stacks to one column when the **content container** (not the viewport) drops to ≤620px.
4. On `#/live`, click 画面设置 (Display), then AI 结果 (Annotate). Measure `.video-wrapper` before and after — width and height must be identical. An Annotate/overlay toggle that resizes or recenters the preview is the bug these rules prevent.

## Device safety rules

Before every device write:

- run a read-only preflight;
- identify the exact files that will change;
- read `/userdata/local/apps/mode` and preserve it;
- record whether `S03node-red`/`K03node-red`, `S91sscma-node`/`K91sscma-node`, and `S93sscma-supervisor` exist;
- create a timestamped backup under `/userdata/local/backups`;
- upload to `/tmp`, validate there, then replace;
- keep a rollback trap active until post-deploy health checks pass.

Never delete the Node-RED, sscma-node, or Supervisor init scripts. Never change reCamera Studio/Node-RED mode merely to deploy management code. Do not reboot for a frontend-only change. Do not call a routine frontend/backend copy a firmware flash; full firmware flashing is a separate, higher-risk operation and needs an explicit request.

Read [safety-and-rollback.md](references/safety-and-rollback.md) before deploying.

## Deployment entry points

Both deployment scripts are inert unless `--apply` is present. First inspect their plan:

```bash
/home/steven/.gemini/skills/reweb/scripts/deploy-web.sh --dry-run
```

```bash
/home/steven/.gemini/skills/reweb/scripts/deploy-supervisor.sh --dry-run
```

```bash
/home/steven/.gemini/skills/reweb/scripts/deploy-runtime-scripts.sh --dry-run
```

The dedicated `deploy-runtime-scripts.sh` deploys ONLY `main.sh` + `upgrade.sh`
to `/usr/share/supervisor/scripts/` with its own backup under
`reweb-<ts>-scripts`, a remote `bash -n` gate, an on-device OSS-URL content
check, and a live behavior probe (`upgrade.sh latest` must attempt the OSS
release URL). It never touches the supervisor binary and never restarts the
service (scripts are spawned per request, so replacement is immediately
effective). Prefer it for firmware-channel/shell-script-only changes. Its
firmware channel currently points at RobotXTeam/OSS-reCamera-solutions
(GitHub Releases + firmware/latest.json metadata), with the legacy
files.seeedstudio.com/reCamera md5sum/url.txt layout as fallback.

Run the matching dry-run before every deployment, then use `--apply` as the default final step for a completed and verified routine change under the standing authorization above. `deploy-web.sh` builds and swaps only `/usr/share/supervisor/www`; it does not restart the device. `deploy-supervisor.sh` builds and replaces the management binary, optionally the runtime shell/init files with `--include-runtime`, and restarts only Supervisor while preserving the persisted mode. NOTE: if the freshly-built supervisor binary fails the post-start process check, `deploy-supervisor.sh` rolls back and `--include-runtime` therefore does NOT deploy the repo scripts — use `deploy-runtime-scripts.sh` when only shell scripts (main.sh/upgrade.sh) need to change.

If the standard deployment script does not include every newly required artifact, extend and verify the script first or use an equivalently staged, backed-up, rollback-protected deployment. Never silently omit a runtime dependency.

## Verification standard

A task is complete only when the relevant boundary is exercised:

- frontend: Vite production build plus browser-tool interaction against real APIs/WS;
- backend: cross-build plus real device endpoint/process verification after an authorized deploy;
- WebSocket work: inspect the actual upgrade/request and UI connection state;
- mode-sensitive work: prove the mode file is unchanged and expected services still match that mode;
- deployment: report the backup path and exact rollback command.

If a check cannot run, state exactly what was skipped and why. See [troubleshooting.md](references/troubleshooting.md).

## New-conversation invocation

Use either form:

```text
/reweb 继续开发 reCamera web，启动隧道和本地预览
```

```text
/reweb Continue the reCamera Studio project. Start the tunnels and preview, inspect current git changes, implement <task>, verify it, then deploy it through the backed-up workflow.
```

```text
Use the reweb skill to modify the Supervisor backend for <task>, cross-build it, and prepare a dry-run deployment plan for the live device.
```

The skill supplies the durable environment and safety procedure; the repository and git diff remain the source of truth for current implementation state.
