#!/usr/bin/env bash
set -euo pipefail

# Install outside /config, which is replaced by a persistent volume at runtime.
export HOME=/opt/claude
mkdir -p "$HOME"
curl --fail --show-error --location --retry 3 \
    https://claude.ai/install.sh -o /tmp/install-claude.sh
bash /tmp/install-claude.sh "${CLAUDE_VERSION:-stable}"
install -m 0755 "$(readlink -f "$HOME/.local/bin/claude")" /usr/local/bin/claude
rm -rf /opt/claude /tmp/install-claude.sh
claude --version
