# Troubleshooting

## Preview never loads

- Verify Vite and listeners: `ss -ltn | grep -E ':(5173|18080|18081|18082|18083)\b'`.
- Confirm the Browser Preview configuration uses `cwd: solutions/supervisor/www`.
- If Vite started from the repo root, `package.json` is not found; stop it and use the configured `supervisor-webui` entry.
- Confirm tunnels are present; see the preflight script's device HTTP check.

## Blank or proxy error in console

- Missing tunnel: start tunnels before reloading.
- Wrong origin: ensure the app reads `deviceProxy.ts`; a raw `new URL("ws://...")` with empty base becomes blank.
- API returning SPA HTML with HTTP 200: `supervisorRequest.ts` validates content type and body; trace the C++ handler or request the feature's state through the API first.

## WebSocket upgrade fails

- `/nodered`, `/terminal-ws`, `/debug-ws` require `ws: true` in the Vite proxy and matching remote ports. Check `vite.config.ts` and `deviceProxy.ts`.
- ttyd must be reachable on the device; verify the tunnel and the `recamera-terminal` component's URL resolution.
- If the UI shows a blank terminal, use `preview_console_logs` and `preview_network` to see whether the upgrade request was issued and whether it returned 101.

## Repeated HMR/type errors after deletion

- Remove dead imports and unused i18n keys.
- TypeScript strict/noUnusedLocals fail the production build; do not suppress by editing tsconfig.
- Check for leftover JSX fragments after deleting a block.

## Deploy script fails

- Cross-build must complete before deployment; never skip the build step.
- Disk full: check `/userdata` free space; do not replace Supervisor with a partially staged file.
- Mode mismatch after stop: restore from the backup path reported by the script; do not leave the service stopped.
- `sudo` prompts: run the script with `RECAMERA_SUDO_PASSWORD` in the environment or ensure passwordless sudo for the operator account. Do not pipe a password into generated config files.

## Camera conflicts

- A gallery app and Node-RED cannot both own the camera; mode file and S/K prefixes decide.
- Do not `kill -9` camera services as part of a routine deploy. Stop only the Supervisor when needed.
- If the device is stuck in an unknown mode, use the existing `legacy `.force_console`` recovery path through `setRunMode` or the force-Studio UI, not a manual service deletion.

## Restore after aggressive cleanup

- If a recovery operation killed all camera services, reboot the device only after verifying the persisted mode and S/K prefixes are correct for that mode.
- After reboot, verify `http://192.168.2.102/api/version` (through the tunnel if needed) before continuing.

## Git and workspace integrity

- Before each session, inspect `git status`; do not discard existing modifications unless the user explicitly authorizes it.
- Local configuration files such as `.claude/launch.json` and `deviceProxy.ts` are intentionally untracked or modified; preserve them.
- Keep deployment artifacts (`dist`, `*.deb`) out of commits unless the project's `.gitignore` already includes them.
