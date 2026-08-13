# Device Layout

## Connection

Default route:

```text
workstation -> SSH OpenWrt root@10.88.92.200 -> TCP 192.168.2.102
```

Override targets without editing scripts:

- `OPENWRT_SSH_TARGET`
- `RECAMERA_HOST`
- `RECAMERA_USER`
- `RECAMERA_PASSWORD` (environment only, optional fallback)
- `RECAMERA_SUDO_PASSWORD` (environment only, required for privileged deploys unless sudo is passwordless)

The wrappers use OpenSSH `ProxyCommand` through the OpenWrt target. They do not place secrets in generated SSH config.

## Services and ports

- Supervisor HTTP/UI: `80`
- Node-RED: `1880`
- ttyd: `9090`
- Debug/video WebSocket: `8001`
- RTSP used by gallery apps: commonly `8554`

Important init entries:

- `/etc/init.d/S93sscma-supervisor`
- `/etc/init.d/S03node-red` or parked `/etc/init.d/K03node-red`
- `/etc/init.d/S91sscma-node` or parked `/etc/init.d/K91sscma-node`

Never delete these scripts. S/K prefixes encode the intended boot ownership of the camera.

## Supervisor files

- Binary: `/usr/local/bin/supervisor`
- Web root: `/usr/share/supervisor/www`
- Runtime command script: `/usr/share/supervisor/scripts/main.sh`
- Add-on scripts/catalog: `/usr/share/supervisor/addons`
- App catalog/docs/models: `/usr/share/supervisor/apps`, `/usr/share/supervisor/models`
- Log: `/userdata/local/logs/supervisor.log`

## Persistent application state

- Run mode: `/userdata/local/apps/mode`
- Active app and app metadata: under `/userdata/local/apps`
- Add-on state/logs: `/userdata/local/addons`
- Recordings: `/userdata/recordings`
- Safe deployment backups: `/userdata/local/backups/reweb-*`

Treat `/userdata` as persistent user state. Back it up selectively and never replace its directories with package defaults.

## Read-only health snapshot

The preflight script collects:

- device identity/version API;
- mode file;
- init-script S/K state;
- Supervisor/Node/Node-RED processes;
- filesystem free space;
- local tunnel listeners.

This snapshot is safe to run before code changes. A deploy script captures the same state inside its backup directory before writing.
