#!/usr/bin/env bash
set -euo pipefail
[[ "$(dpkg --print-architecture)" == amd64 ]]
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT
# Official GUI build also provides CLI, TUI, and web subcommands.
curl -fsSL --retry 3 --max-time 300 "$MAGPIE_URL" -o "$TEMP_FILE"
printf '%s  %s\n' "$MAGPIE_SHA256" "$TEMP_FILE" | sha256sum -c -
install -m 0755 "$TEMP_FILE" /usr/local/bin/magpie
# No provider imports, agent rewrites, login, or autostart during installation.
/usr/local/bin/magpie --help >/dev/null
