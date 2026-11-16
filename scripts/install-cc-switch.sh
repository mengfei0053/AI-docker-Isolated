#!/usr/bin/env bash
set -euo pipefail
[[ "$(dpkg --print-architecture)" == amd64 ]]
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
curl -fsSL --retry 3 --max-time 300 "$CC_SWITCH_URL" -o "$TEMP_DIR/cc-switch.deb"
# Pinned checksum from the official GitHub release asset metadata.
printf '%s  %s\n' "$CC_SWITCH_SHA256" "$TEMP_DIR/cc-switch.deb" | sha256sum -c -
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    "$TEMP_DIR/cc-switch.deb"
rm -rf /var/lib/apt/lists/*
command -v cc-switch
