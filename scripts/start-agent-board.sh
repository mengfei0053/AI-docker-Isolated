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
if [[ -z "${DATABASE_URL:-}" ]]; then
    printf 'Agent Board requires PostgreSQL. Set DATABASE_URL in %s\n' "$CONFIG_FILE" >&2
    printf 'Example: postgresql://USER:PASSWORD@HOST:5432/agent_board\n' >&2
    printf 'This launcher has not created or modified any database.\n' >&2
    exit 1
fi
export DATA_DIR="${DATA_DIR:-$HOME/.local/share/agent-board}"
export HOST="${HOST:-127.0.0.1}"
export PORT="${PORT:-8791}"
mkdir -p "$DATA_DIR"
cd /opt/agent-board
printf 'Agent Board starting on http://%s:%s (Ctrl+C to stop)\n' "$HOST" "$PORT"
exec pnpm start
