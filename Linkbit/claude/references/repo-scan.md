# Linkbit Repo Scan

Scan date: 2026-04-29

## Top-level runtime components

- `cmd/linkbit-controller/main.go`: controller entrypoint, sqlite migration, API + static web serving.
- `cmd/linkbit-relay/main.go`: relay node entrypoint, DERP-like service and heartbeat loop.
- `cmd/linkbit-agent/main.go`: agent runtime and `forward` subcommand.

## Controller ownership

- `internal/controller/server.go`: API routes and auth boundaries.
- `internal/controller/tcp_relay.go`: TCP relay session create/pending/stream attach.
- `internal/controller/wireguard_hub.go`: hub peer management (when enabled).
- `internal/controller/derpmap.go`: DERP map synthesis from relay registry.
- `internal/controller/static.go`: static web serving.

Important routes:

- `POST /api/v1/invitations`: create enrollment key.
- `POST /api/v1/devices/register`: first-time enrollment with invitation token.
- `GET /api/v1/devices/{id}/network-config`: per-device network/policy view.
- `POST /api/v1/policies`: creates allow rules for peer reachability and relay targeting.
- `POST /api/v1/relay/sessions`: request relay session from source side.
- `GET /api/v1/relay/sessions/pending`: long-poll by target agent.
- `GET /api/v1/relay/client/{id}` and `GET /api/v1/relay/agent/{id}`: upgraded stream endpoints.

Auth headers:

- `X-Linkbit-API-Key`: admin/relay control-plane APIs.
- `X-Linkbit-Device-ID` and `X-Linkbit-Device-Token`: device-scoped APIs/relay.

## Agent ownership

- `internal/agent/agent.go`: load persisted state, first registration, tunnel apply, health report loop, relay poll enable.
- `internal/agent/client.go`: HTTP registration/network-config/relay client.
- `internal/agent/wireguard.go`: WireGuard interface lifecycle.
- `internal/agent/tcp_relay.go`: relay target and local forwarding client behavior.
- `internal/agent/state.go`: persisted device credentials and keys.

## Config ownership

- `internal/config/config.go`: env var contract for controller/relay/agent.
- `deploy/*.env.example`: env templates for deployment.
- `deploy/install-*.sh`: systemd install scripts for controller, relay, and agent.

## Web console ownership

- `web/src/pages/DashboardPage.tsx`: invitation, policy, relay, device lifecycle UI.
- `web/src/lib/api.ts`: API client shapes and request wrappers.

## Script map

- `scripts/build-linux-amd64.sh`: build controller/relay/agent binaries plus web build.
- `scripts/render-deploy-env.sh`: render controller and relay env files.
- `scripts/remote-install.sh`: upload controller/relay artifacts to remote host.
- `scripts/remote-health.sh`: public health and overview checks.
- `scripts/smoke-api.sh`: local smoke test including invitation and registration flow.

## Operational caveats

- `scripts/remote-install.sh` does not install remote Ubuntu agent devices.
- Forwarding success depends on policy permissions and target service availability.
- Invitation token is not persistent credential; state file becomes source of truth after first registration.

