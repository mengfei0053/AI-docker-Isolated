#!/usr/bin/env bash
set -euo pipefail
[[ "$(dpkg --print-architecture)" == amd64 ]]
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# The IDE archive is pinned to an official download and its observed SHA-256.
curl -fsSL --retry 3 --max-time 600 "$ANTIGRAVITY_IDE_URL" \
    -o "$TEMP_DIR/ide.tar.gz"
printf '%s  %s\n' "$ANTIGRAVITY_IDE_SHA256" "$TEMP_DIR/ide.tar.gz" | sha256sum -c -
mkdir -p /opt/antigravity-ide
tar -xzf "$TEMP_DIR/ide.tar.gz" --strip-components=1 -C /opt/antigravity-ide
chown root:root /opt/antigravity-ide/chrome-sandbox
chmod 4755 /opt/antigravity-ide/chrome-sandbox
ln -s /opt/antigravity-ide/bin/antigravity-ide /usr/local/bin/antigravity-ide
# Compatibility alias for tools that look for the older IDE command name.
ln -s /opt/antigravity-ide/bin/antigravity-ide /usr/local/bin/antigravity

# Separate official terminal agent, not the IDE's command-line file launcher.
# SHA-512 comes from Google's official CLI updater manifest.
curl -fsSL --retry 3 --max-time 600 "$ANTIGRAVITY_CLI_URL" \
    -o "$TEMP_DIR/cli.tar.gz"
printf '%s  %s\n' "$ANTIGRAVITY_CLI_SHA512" "$TEMP_DIR/cli.tar.gz" | sha512sum -c -
tar -xzf "$TEMP_DIR/cli.tar.gz" -C "$TEMP_DIR" antigravity
install -m 0755 "$TEMP_DIR/antigravity" /usr/local/bin/agy
/usr/local/bin/agy --help >/dev/null
