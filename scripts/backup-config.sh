#!/usr/bin/env bash
# Stop only the desktop for a consistent browser/database backup, then resume it.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups/docker-webtop}"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
ARCHIVE="$BACKUP_DIR/config-$(date +%Y%m%d-%H%M%S).tar.zst"
PARTIAL="$ARCHIVE.partial"
DESKTOP_ID=$(docker compose ps -aq webtop)
DESKTOP_RUNNING=false
if [[ -n "$DESKTOP_ID" ]]; then
    DESKTOP_RUNNING=$(docker inspect --format '{{.State.Running}}' "$DESKTOP_ID")
fi
resume() {
    if [[ "$DESKTOP_RUNNING" == true ]]; then
        docker compose start webtop
    fi
}
trap resume EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ "$DESKTOP_RUNNING" == true ]]; then
    docker compose stop -t 60 webtop
fi
# Do not dereference symlinks: /config/projects points outside this backup scope.
tar --acls --xattrs -I 'zstd -T2 -3' -cf "$PARTIAL" config
zstd --test --quiet "$PARTIAL"
tar -I zstd -tf "$PARTIAL" >/dev/null
mv "$PARTIAL" "$ARCHIVE"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
chmod 600 "$ARCHIVE" "$ARCHIVE.sha256"
printf 'Verified backup: %s\n' "$ARCHIVE"
du -h "$ARCHIVE"
