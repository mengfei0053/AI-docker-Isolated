#!/usr/bin/env bash
set -euo pipefail
# Stop when upstream changes: review and port this fix rather than silently
# overwriting a future version's filesystem security rules.
printf '%s  %s\n' \
    a69d19015448ef2041d6e526bec4a682a11fad0439a9d4c8ca599e1cc9df718e \
    /opt/agent-board/src/fsbrowse.ts | sha256sum -c -
install -m 0644 /tmp/board-browse/fsbrowse.ts.in /opt/agent-board/src/fsbrowse.ts
install -m 0644 /tmp/board-browse/fsbrowse.test.ts.in /opt/agent-board/src/fsbrowse.test.ts
TEST_HOME=$(mktemp -d /var/tmp/board-browse-home-XXXXXX)
trap 'rm -rf "$TEST_HOME" /tmp/board-browse' EXIT
cd /opt/agent-board
HOME="$TEST_HOME" node --import tsx --test src/fsbrowse.test.ts
