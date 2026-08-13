# Architecture

## Request path during local development

```text
Browser http://127.0.0.1:5173
  -> Vite
     /api/*         -> 127.0.0.1:18080 -> OpenWrt -> 192.168.2.102:80
     /nodered/*     -> 127.0.0.1:18081 -> OpenWrt -> 192.168.2.102:1880
     /terminal-ws/* -> 127.0.0.1:18082 -> OpenWrt -> 192.168.2.102:9090
     /debug-ws/*    -> 127.0.0.1:18083 -> OpenWrt -> 192.168.2.102:8001
```

The active proxy definitions are in `solutions/supervisor/www/vite.config.ts`. Runtime URL selection is centralized in `src/utils/deviceProxy.ts`; use it instead of constructing service URLs ad hoc.

Key consumers:

- Supervisor Axios: `src/utils/supervisorRequest.ts`
- Node-RED Axios and URL helpers: `src/utils/noderedRequest.ts`, `src/utils/noderedUrl.ts`
- App/debug streams: `src/utils/appStream.ts`
- ttyd: `src/components/recamera-terminal/Terminal.tsx`

Production runs from the device origin and talks directly to device ports. Development deliberately uses same-origin Vite paths so the Browser Preview sandbox never needs direct access to the private device network.

## Frontend structure

- Router: `src/router/index.tsx` (React Router, hash router at app bootstrap)
- Main sidebar model: `src/layout/menu.ts`
- Main shell: `src/components/recamera-shell`
- Device subnavigation: `src/components/common-popup/DeviceInfoShell.tsx`
- Shared device-page styling: `src/components/common-popup/rv1126b.css`
- New console pages/shared styling: `src/components/app-config/recamera-new-pages.css`
- State: Zustand stores under `src/store`
- i18n: `src/locales/zh-CN.json`, `src/locales/en-US.json`

Keep routing aliases compatible where practical. A removed feature should have no visible navigation or live route, but an explicit redirect is preferable to a broken static request.

## Supervisor backend

- C++ API registration/handlers: `solutions/supervisor/main/include`, `main/src`
- Shell-backed system operations: `solutions/supervisor/rootfs/usr/share/supervisor/scripts/main.sh`
- Service lifecycle and boot mode reconciliation: `rootfs/etc/init.d/S93sscma-supervisor`
- Package lifecycle: `solutions/supervisor/control/*`
- Web assets in package: `solutions/supervisor/rootfs/usr/share/supervisor/www`

The executable is installed as `/usr/local/bin/supervisor`. The HTTP API frequently delegates to `main.sh`; trace both layers before changing a contract.

## Device run modes

`/userdata/local/apps/mode` contains `console` or `nodered`.

- `console`: Supervisor gallery application owns the camera; Node-RED and sscma-node are parked (`K03...`, `K91...`).
- `nodered`: Node-RED/sscma-node own the camera and are armed (`S03...`, `S91...`).

Use the existing `deviceMgr/getRunMode`, `setRunMode`, and force-console implementation for product behavior. Deployment must not switch modes as a convenience. Restarting Supervisor reads and reconciles the persisted mode.

## Build boundaries

- Frontend only: `npm --prefix solutions/supervisor/www run build`
- Supervisor without rebuilding web: CMake with `WEB=OFF` (default)
- Supervisor package with current web: CMake with `WEB=ON`, then package
- Package output: `supervisor_0.3.1_riscv64.deb` (version follows CMake project)

For rapid frontend development, deploy only `dist` when authorized. For C++ or runtime shell/init changes, deploy a package or the narrowly selected artifacts through the backed-up Supervisor deployment script.
