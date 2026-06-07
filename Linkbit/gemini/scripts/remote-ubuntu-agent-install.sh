#!/usr/bin/env sh
set -eu

# End-to-end helper for remote Ubuntu Linkbit agent install + enrollment.
# Required env:
#   LINKBIT_REMOTE_HOST      e.g. ubuntu@203.0.113.10
#   LINKBIT_CONTROLLER_URL   e.g. http://120.79.155.227
#   LINKBIT_ADMIN_KEY        admin API key
# Optional env:
#   LINKBIT_DEVICE_NAME      default: ubuntu-remote
#   LINKBIT_ENROLLMENT_KEY   if absent, script will create one
#   LINKBIT_LOCAL_AGENT_BIN  default: ./bin/linkbit-agent
#   LINKBIT_REMOTE_DIR       default: ~/.steven/Linkbit
#   LINKBIT_SOURCE_DEVICE_ID source device for policy creation
#   LINKBIT_POLICY_PORTS     default: 22,3389,4000

remote_host="${LINKBIT_REMOTE_HOST:?LINKBIT_REMOTE_HOST is required}"
controller_url="${LINKBIT_CONTROLLER_URL:?LINKBIT_CONTROLLER_URL is required}"
admin_key="${LINKBIT_ADMIN_KEY:?LINKBIT_ADMIN_KEY is required}"
device_name="${LINKBIT_DEVICE_NAME:-ubuntu-remote}"
local_agent_bin="${LINKBIT_LOCAL_AGENT_BIN:-./bin/linkbit-agent}"
remote_dir="${LINKBIT_REMOTE_DIR:-~/.steven/Linkbit}"
source_device_id="${LINKBIT_SOURCE_DEVICE_ID:-}"
policy_ports="${LINKBIT_POLICY_PORTS:-22,3389,4000}"
token="${LINKBIT_ENROLLMENT_KEY:-}"

if [ ! -x "$local_agent_bin" ]; then
  echo "missing executable agent binary: $local_agent_bin" >&2
  echo "run .tools/go/bin/go build -o bin/linkbit-agent ./cmd/linkbit-agent first" >&2
  exit 1
fi

if [ -z "$token" ]; then
  token="$(
    curl -fsS "$controller_url/api/v1/invitations" \
      -H "X-Linkbit-API-Key: $admin_key" \
      -H "Content-Type: application/json" \
      -d '{"userId":"default-user","groupId":"default","expiresInSeconds":86400}' \
    | jq -r '.token'
  )"
fi

if [ -z "$token" ] || [ "$token" = "null" ]; then
  echo "failed to create/read enrollment token" >&2
  exit 1
fi

ssh "$remote_host" "mkdir -p '$remote_dir'/bin '$remote_dir'/deploy"
scp "$local_agent_bin" "$remote_host:$remote_dir/bin/linkbit-agent"
scp ./deploy/install-agent.sh "$remote_host:$remote_dir/deploy/install-agent.sh"

ssh "$remote_host" "sudo apt-get update && sudo apt-get install -y wireguard-tools iproute2 ca-certificates openssh-server"

ssh "$remote_host" "sudo mkdir -p /etc/linkbit && sudo tee /etc/linkbit/agent.env >/dev/null" <<EOF
LINKBIT_CONTROLLER_URL=$controller_url
LINKBIT_ENROLLMENT_KEY=$token
LINKBIT_DEVICE_NAME=$device_name
LINKBIT_HEALTH_SECONDS=300
LINKBIT_WG_INTERFACE=linkbit0
LINKBIT_WG_DRY_RUN=true
LINKBIT_STATE_PATH=/var/lib/linkbit/agent-state.json
LINKBIT_TCP_RELAY_ENABLED=true
LINKBIT_TRANSPARENT_TCP=false
LINKBIT_RUN_ONCE=false
EOF

ssh "$remote_host" "cd '$remote_dir' && sudo ./deploy/install-agent.sh"
ssh "$remote_host" "sudo systemctl is-active linkbit-agent"
ssh "$remote_host" "sudo journalctl -u linkbit-agent -n 120 --no-pager | grep -q 'tcp relay target enabled'"

target_device_id="$(
  for _ in $(seq 1 30); do
    devices="$(curl -fsS "$controller_url/api/v1/devices" -H "X-Linkbit-API-Key: $admin_key")"
    id="$(printf '%s' "$devices" | jq -r --arg name "$device_name" '.[] | select(.name == $name) | .id' | head -n 1)"
    if [ -n "$id" ] && [ "$id" != "null" ]; then
      printf '%s' "$id"
      exit 0
    fi
    sleep 2
  done
  exit 1
)"

if [ -n "$source_device_id" ]; then
  policy_id="local-to-$device_name-tcp"
  ports_json="$(printf '%s' "$policy_ports" | jq -R 'split(",") | map(gsub("^ +| +$"; ""))')"
  curl -fsS -m 10 -X DELETE \
    -H "X-Linkbit-API-Key: $admin_key" \
    "$controller_url/api/v1/policies/$policy_id" >/dev/null || true
  jq -n \
    --arg id "$policy_id" \
    --arg name "Local to $device_name TCP" \
    --arg source "$source_device_id" \
    --arg target "$target_device_id" \
    --argjson ports "$ports_json" \
    '{id:$id,name:$name,sourceId:$source,targetId:$target,ports:$ports,protocol:"tcp",enabled:true}' \
  | curl -fsS "$controller_url/api/v1/policies" \
      -H "X-Linkbit-API-Key: $admin_key" \
      -H "Content-Type: application/json" \
      -d @- >/dev/null
fi

echo "remote agent installed on $remote_host as device '$device_name' ($target_device_id)"
