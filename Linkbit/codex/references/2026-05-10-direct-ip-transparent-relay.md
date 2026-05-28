# 2026-05-10 Direct-IP Transparent Relay Worklog

Use this when continuing the May 10 Linkbit desktop/direct-IP work or when onboarding new devices after this change.

## User-facing Product Shape

- Remove the old local-forward controls from the desktop app:
  - `本地监听`
  - `远端目标`
  - `启动 SSH/RDP 中转`
  - `停止中转`
- The desktop app should show remote target names, Linkbit IPs, and service addresses such as:
  - `10.88.222.222:22 / 10.88.222.222:3389 / 10.88.222.222:4000`
  - `10.88.226.245:22 / 10.88.226.245:3389 / 10.88.226.245:4000`
  - `10.88.92.200:22 / 10.88.92.200:3389 / 10.88.92.200:4000`
- Do not explain relay/TUN/WireGuard internals in the app. User experience should be direct IP access.
- The right side target panel should align visually with the log panel and expand into the removed local-forward area.

## Implemented Local Behavior

- Local workstation agent uses transparent TCP relay:
  - `LINKBIT_TRANSPARENT_TCP=true`
  - listen: `127.0.0.1:15088`
  - network: `10.88.0.0/16`
  - iptables NAT chain: `LINKBIT_TPROXY`
- Verification commands:

```bash
systemctl is-active linkbit-agent
sudo iptables -t nat -S | rg 'LINKBIT|10\.88|15088'
ss -lntp | rg '15088|linkbit-agent'
```

- Expected local log line:

```text
tcp relay target enabled
transparent tcp relay enabled
```

- Important: `nc 10.88.x.x <port>` may report that the TCP connection succeeded because the local transparent proxy accepted the socket. Use SSH banner/login or target-side logs as proof.

## Controller and Cloud State

- Controller URL used in this run: `http://120.79.155.227`
- Cloud root access was available during the run, but cloud security groups / provider UDP ingress cannot be changed from inside the ECS guest alone.
- `LINKBIT_HUB_WG_ENDPOINT` was corrected from a Tailscale CGNAT address to public `120.79.155.227:443`.
- Packet capture showed local UDP could leave the workstation but cloud `eth0` did not receive the expected UDP packets; do not spend more time on UDP/WireGuard unless Alibaba security group/provider networking is fixed.
- TCP relay is the reliable product path for now.

## Code Changes From This Work

- Desktop:
  - `desktop/src/main.js`
  - `desktop/src/preload.js`
  - `desktop/src/renderer.html`
- Agent/config:
  - `internal/config/config.go`
  - `internal/agent/agent.go`
  - `internal/agent/transparent_tcp.go`
  - `internal/agent/agent_test.go`
- Controller WireGuard endpoint guard:
  - `internal/controller/wireguard_hub.go`
  - `internal/controller/server_test.go`
- Packaging/deploy defaults:
  - `deploy/agent.env.example`
  - `packaging/linux/linkbit-agent-configure`
  - `scripts/remote-ubuntu-agent-install.sh`

Key behavioral change in `internal/agent/agent.go`: start TCP relay target polling before attempting WireGuard. If WireGuard apply fails and relay is enabled, log a warning and continue; do not exit before relay is available.

## New Default Agent Config

For remote target devices:

```env
LINKBIT_CONTROLLER_URL=http://120.79.155.227
LINKBIT_ENROLLMENT_KEY=<fresh-token>
LINKBIT_DEVICE_NAME=<device-name>
LINKBIT_HEALTH_SECONDS=300
LINKBIT_WG_INTERFACE=linkbit0
LINKBIT_WG_DRY_RUN=true
LINKBIT_STATE_PATH=/var/lib/linkbit/agent-state.json
LINKBIT_TCP_RELAY_ENABLED=true
LINKBIT_TRANSPARENT_TCP=false
LINKBIT_RUN_ONCE=false
```

For the local workstation/source device, transparent TCP is enabled by default in code and installed service:

```env
LINKBIT_TRANSPARENT_TCP=true
LINKBIT_TRANSPARENT_TCP_LISTEN=127.0.0.1:15088
LINKBIT_TRANSPARENT_TCP_NETWORK=10.88.0.0/16
```

## New Device Onboarding

Use the repo helper, not `scripts/remote-install.sh`:

```bash
.tools/go/bin/go build -o bin/linkbit-agent ./cmd/linkbit-agent
LINKBIT_REMOTE_HOST=<user@host> \
LINKBIT_CONTROLLER_URL=http://120.79.155.227 \
LINKBIT_ADMIN_KEY=<admin-key> \
LINKBIT_DEVICE_NAME=<name> \
LINKBIT_SOURCE_DEVICE_ID=<local-source-device-id> \
scripts/remote-ubuntu-agent-install.sh
```

The helper installs the current local binary, writes relay-first config, verifies `tcp relay target enabled`, waits for the device to appear in the controller, and creates a `22,3389,4000` TCP policy when `LINKBIT_SOURCE_DEVICE_ID` is provided.

## May 10 Device Status

Source/local device:

- Name in controller during this run: `steven-ubuntu`
- Linkbit IP: `10.88.235.251`
- Device ID: `93845d4a-d1cb-4306-b03c-f69c59e775c5`
- Local sudo password was supplied in chat for this session; do not hardcode it in repo docs.

Targets:

- `seeed`
  - Linkbit IP: `10.88.222.222`
  - Device ID: `6192879a-04ae-4594-b27e-8b8a3f9843cd`
  - Verified direct IP SSH after upgrade:
    `ssh seeed@10.88.222.222 'hostname; echo linkbit-final-ok'`
  - Remote binary `/opt/linkbit/linkbit-agent` matched local `bin/linkbit-agent` sha256:
    `63df0bce9d99358d77be0233e5cf05bf5a7587dcf078dc96d018717212aa4937`
  - Remote env confirmed:
    `LINKBIT_WG_DRY_RUN=true`, `LINKBIT_TCP_RELAY_ENABLED=true`, `LINKBIT_TRANSPARENT_TCP=false`
  - Remote log confirmed `tcp relay target enabled`.
- `steven`
  - Linkbit IP: `10.88.226.245`
  - Device ID: `a98449c0-17df-4cb1-bd79-df77a6e0d846`
  - Still not fixed on May 10 because the target was offline/unreachable for management.
  - Tailscale showed `steven` offline with last seen `2026-05-08T06:42:36Z`.
  - Linkbit direct SSH still timed out during SSH banner exchange.
- `friendlywrt`
  - Linkbit IP: `10.88.92.200`
  - Device ID: `d89822b1-14c0-49f5-8dae-ea9b6b55db3e`
  - Still not fixed on May 10 because the target was offline/unreachable for management.
  - Tailscale showed `FriendlyWrt` offline with last seen `2026-05-09T10:21:09Z`.
  - Linkbit direct SSH still timed out during SSH banner exchange.

## Policies

The controller policy set was normalized to allow `22,3389,4000` from local source `93845d4a-d1cb-4306-b03c-f69c59e775c5` to each target:

- `local-to-seeed-tcp`
- `local-to-steven-tcp`
- `local-to-friendlywrt-tcp`

If a device is re-enrolled and gets a new device ID, recreate the policy because policies target IDs, not names.

## Clash/Tailscale Interaction During Repair

Clash Verge/Mihomo TUN created a `Meta` interface, fake-IP DNS in `198.18.0.0/16`, and policy table `2022`. During this run it caused:

- `controlplane.tailscale.com` resolving to `198.18.0.4`
- Tailscale going `NoState`
- `100.64.0.0/10` SSH attempts appearing to connect but hanging at SSH banner

Temporary repair path:

```bash
sudo systemctl stop clash-verge-service.service
sudo systemctl restart tailscaled
tailscale status
```

After repair, restore:

```bash
sudo systemctl start clash-verge-service.service
systemctl is-active clash-verge-service.service
tailscale status --json | jq -r '.BackendState'
systemctl is-active linkbit-agent
```

Do not confuse this with Linkbit product routing. Tailscale was only a management path for reaching devices; Linkbit product traffic should use `120.79.155.227` TCP relay and direct `10.88.x.x` service addresses.

## Verification Checklist

Before calling Linkbit connectivity done:

1. Local source:
   - `systemctl is-active linkbit-agent`
   - `sudo iptables -t nat -S | rg 'LINKBIT|10\.88|15088'`
   - logs contain `tcp relay target enabled` and `transparent tcp relay enabled`
2. Controller:
   - `/api/v1/devices` shows current target IDs
   - `/api/v1/policies` has source ID to target ID with `22,3389,4000`
3. Target:
   - target agent service active
   - target logs contain `tcp relay target enabled`
   - target has the current binary if old release hangs before relay target polling
4. Real client:
   - SSH login or protocol banner succeeds through `10.88.x.x:22`
   - RDP/NoMachine/etc. only counted as working if the remote service exists and the client reaches it

If `10.88.x.x:22` times out during banner exchange, the target-side agent/service is the first suspect. Do not declare it a local transparent proxy problem until target logs prove relay polling is active and attaching sessions.
