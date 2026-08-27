#!/bin/sh
# Build the de-injection payload for restore-nodered-vanilla.sh from:
#   - the stock baseline archive captured from the factory device
#   - the exact npm package tarballs matching the installed versions
set -eu

SKILL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SKILL_DIR/scripts/lib.sh"

BASELINE_DIR="$REPO/.reweb-backups/nodered-original-192.168.42.1-20260816"
OUT="${1:-$REPO/.reweb-backups/nodered-vanilla-payload.tar.gz}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[ -s "$BASELINE_DIR/nodered-baseline.tar.gz" ] || die "baseline archive missing"
( cd "$BASELINE_DIR" && sha256sum -c SHA256SUMS ) || die "baseline checksums failed"

note "fetching stock npm tarballs (versions must match the device install)"
cd "$WORK"
npm pack node-red-contrib-sscma@0.3.6 --silent
npm pack node-red-contrib-seeed-recamera@0.0.9 --silent
npm pack @flowfuse/node-red-dashboard@1.26.0 --silent
for t in *.tgz; do mkdir -p "${t%.tgz}" && tar -xzf "$t" -C "${t%.tgz}"; done

mkdir -p payload
tar -xzf "$BASELINE_DIR/nodered-baseline.tar.gz" -C "$WORK" .node-red/settings.js
cp "$WORK/.node-red/settings.js"                                  payload/settings.js
cp "$WORK/node-red-contrib-sscma-0.3.6/package/nodes/camera.js"   payload/camera.js
cp "$WORK/node-red-contrib-seeed-recamera-0.0.9/package/nodes/light.js" payload/light.js
cp "$WORK/flowfuse-node-red-dashboard-1.26.0/package/dist/index.html" payload/dashboard-index.html
cp "$WORK/flowfuse-node-red-dashboard-1.26.0/package/dist/favicon.ico" payload/favicon.ico
cp "$WORK/flowfuse-node-red-dashboard-1.26.0/package/dist/apple-touch-icon.png" payload/apple-touch-icon.png
cp "$WORK/flowfuse-node-red-dashboard-1.26.0/package/dist/favicon.svg" payload/favicon.svg

( cd payload && sha256sum * > SHA256SUMS )
tar -czf "$OUT" -C "$WORK/payload" .
note "payload written: $OUT"
( cd "$(dirname "$OUT")" && sha256sum "$(basename "$OUT")" )
