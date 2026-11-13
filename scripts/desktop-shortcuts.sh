#!/usr/bin/with-contenv bash
set -euo pipefail

DESKTOP_DIR="/config/Desktop"
mkdir -p "$DESKTOP_DIR"

for app in adspower_global.desktop virtual-browser-client.desktop \
    ant-browser.desktop 'Cockpit Tools.desktop' agent-board.desktop \
    antigravity-ide.desktop magpie.desktop; do
    src="/usr/share/applications/$app"
    dst="$DESKTOP_DIR/$app"
    if [[ -f "$src" ]]; then
        cp -f "$src" "$dst"
        chmod 0755 "$dst"
        chown abc:abc "$dst"
    fi
done

chown abc:abc "$DESKTOP_DIR"
ln -sfn /projects /config/projects
chown -h abc:abc /config/projects
