# Development Workflow

## Local startup

From any directory:

```bash
/home/steven/.claude/skills/reweb/scripts/preflight.sh
```

```bash
/home/steven/.claude/skills/reweb/scripts/start-tunnels.sh
```

Use Browser Preview configuration `supervisor-webui` from `.claude/launch.json`. It runs `npm run dev -- --host 0.0.0.0` with `solutions/supervisor/www` as cwd.

Confirm listeners with:

```bash
ss -ltn | grep -E ':(5173|18080|18081|18082|18083)\b'
```

## Frontend iteration

1. Inspect the page, request helper, store and i18n keys before editing.
2. Preserve the split between local dev and production URL behavior in `deviceProxy.ts`.
3. Let Vite HMR update the page.
4. Check Browser console and Vite logs before visual assertions.
5. Use accessibility snapshot for text/structure, inspect for exact CSS, and click/fill for interaction.
6. Temporarily resize only for responsive checks; restore the normal adaptive Browser pane afterwards.
7. Run:

```bash
npm --prefix solutions/supervisor/www run build
```

```bash
git diff --check
```

Warnings about stale `caniuse-lite`, browser-externalized `stream` from `jmuxer`, or the Vite chunk-size advisory are known and are not failures unless the current change worsens them.

## Backend tracing

Start at the frontend API function under `www/src/api`, find the C++ registration in `main/src`, then follow any shell command name into `rootfs/usr/share/supervisor/scripts/main.sh`. Check request and response types in matching `.d.ts` files.

Do not return SPA HTML with HTTP 200 for an unsupported API. The frontend request layer intentionally validates content type/body to catch that failure.

## Cross-build

Prerequisites:

```bash
export SG200X_SDK_PATH=/home/steven/sg2002_recamera_emmc
```

```bash
export PATH=/home/steven/host-tools/gcc/riscv64-linux-musl-x86_64/bin:$PATH
```

Backend/package build without refreshing web assets:

```bash
cmake -S solutions/supervisor -B solutions/supervisor/build-live -DCMAKE_BUILD_TYPE=Release -DWEB=OFF
```

```bash
cmake --build solutions/supervisor/build-live -j"$(nproc)"
```

```bash
cmake --build solutions/supervisor/build-live --target package
```

Build including the current frontend:

```bash
cmake -S solutions/supervisor -B solutions/supervisor/build-live-web -DCMAKE_BUILD_TYPE=Release -DWEB=ON
```

```bash
cmake --build solutions/supervisor/build-live-web -j"$(nproc)" --target package
```

The CMake toolchain is `cmake/toolchain-riscv64-linux-musl-x86_64.cmake`; component discovery and SDK paths are in `cmake/project.cmake`.

## Deployment decision

- UI/CSS/router/request change: local Vite verification first; use `deploy-web.sh` only when explicitly asked to install it on the device.
- C++ handler change: use `deploy-supervisor.sh` after a successful cross-build.
- `main.sh` or `S93sscma-supervisor` change: use `deploy-supervisor.sh --include-runtime`; these files alter lifecycle behavior and require stronger verification.
- Full firmware: not part of this routine. Stop and obtain explicit authorization plus a recovery path.

## Stop tunnels

```bash
/home/steven/.claude/skills/reweb/scripts/stop-tunnels.sh
```

The stop script only terminates a process recorded by this skill's PID file and validates its command line before sending a signal.
