#!/usr/bin/env bash
set -euo pipefail
# Optional trusted shell config owned by the desktop user (never baked secrets).
CONFIG_FILE="$HOME/.config/agent-board/env"
if [[ -f "$CONFIG_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    set +a
fi
export DATA_DIR="${DATA_DIR:-$HOME/.local/share/agent-board}"
export HOST="${HOST:-127.0.0.1}"
export PORT="${PORT:-8791}"
# /config/projects is a symlink to the mounted /projects tree.
# Explicitly allow its real path so workspace/task validation accepts it.
export AGENT_BOARD_ALLOWED_ROOTS="${AGENT_BOARD_ALLOWED_ROOTS:-/projects}"
mkdir -p "$DATA_DIR"
cd /opt/agent-board
printf 'Agent Board starting on http://%s:%s (Ctrl+C to stop)\n' "$HOST" "$PORT"
# Avoid runtime package-manager downloads; dependencies are installed in the image.
exec node --import tsx src/server.ts
