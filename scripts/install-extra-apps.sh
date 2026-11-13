#!/usr/bin/env bash
set -euo pipefail
[[ "$(dpkg --print-architecture)" == amd64 ]]

curl -fsSL --retry 3 --max-time 300 "$COCKPIT_TOOLS_URL" \
    -o /tmp/cockpit-tools.deb
printf '%s  %s\n' "$COCKPIT_TOOLS_SHA256" /tmp/cockpit-tools.deb | sha256sum -c -
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    /tmp/cockpit-tools.deb python3 make g++
rm -f /tmp/cockpit-tools.deb
rm -rf /var/lib/apt/lists/*
command -v cockpit-tools

npm install -g pnpm@10.34.9
mkdir -p /opt/agent-board
curl -fsSL --retry 3 --max-time 180 \
    "https://codeload.github.com/mengfei0053/agent-board/tar.gz/${AGENT_BOARD_REF}" \
    -o /tmp/agent-board.tar.gz
tar -xzf /tmp/agent-board.tar.gz --strip-components=1 -C /opt/agent-board
rm /tmp/agent-board.tar.gz
cd /opt/agent-board
# Keep workspace overrides from the upstream lockfile, but skip docs packages.
# Include development dependencies: the server uses tsx at runtime.
npm_config_nodedir=/usr/local pnpm --filter . install --frozen-lockfile
pnpm exec tsx --version
printf '%s\n' "$AGENT_BOARD_REF" > /opt/agent-board/INSTALLED_REVISION
