# Docker Hub mirror; override NODE_IMAGE to use the upstream registry.
ARG NODE_IMAGE=docker.m.daocloud.io/library/node:24-bookworm-slim
FROM ${NODE_IMAGE} AS node
FROM lscr.io/linuxserver/webtop:ubuntu-xfce

USER root
COPY --from=node /usr/local/ /usr/local/

# Docker build proxy args are intentionally NOT persisted in the image.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends \
    ca-certificates curl git jq locales tzdata unzip xdg-utils \
    iproute2 iptables libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
    libxrandr2 libgbm1 libasound2t64 fonts-liberation \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV PUID=1000 \
    PGID=1000 \
    TZ=America/Los_Angeles \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TITLE="Ubuntu Desktop (US-West)" \
    PROXY_HOST=host.docker.internal \
    PROXY_PORT=10810

ARG ADSPOWER_URL=https://version-v2.adspower.net/software/linux-x64-global/8.9.23/AdsPower-Global-8.9.23-x64.deb
ARG VIRTUAL_BROWSER_URL=https://github.com/Virtual-Browser/VirtualBrowser/releases/download/2.4.0/VirtualBrowser-2.4.0-linux-amd64.deb
ARG ANT_BROWSER_URL=https://github.com/black-ant/Ant-Browser/releases/download/V1.8.0/ant-browser-linux-amd64.zip
COPY scripts/install-browsers.sh /tmp/install-browsers.sh
RUN bash /tmp/install-browsers.sh && rm /tmp/install-browsers.sh

ARG CODEX_VERSION=0.167.0
RUN npm install -g "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force && codex --version
ARG CLAUDE_VERSION=stable
COPY scripts/install-claude.sh /tmp/install-claude-native.sh
RUN bash /tmp/install-claude-native.sh && rm /tmp/install-claude-native.sh

COPY scripts/desktop-shortcuts.sh /custom-cont-init.d/20-desktop-shortcuts.sh
RUN chmod +x /custom-cont-init.d/20-desktop-shortcuts.sh

# Restrict WebRTC network paths in browsers that honor Chromium policies.
# This does not disable the WebRTC API or configure vendor profile settings.
COPY --chmod=644 policies/webrtc.json /etc/chromium/policies/managed/webrtc.json
COPY --chmod=644 policies/webrtc.json /etc/opt/chrome/policies/managed/webrtc.json

# Additional applications are installed in a late layer to preserve build cache.
ARG COCKPIT_TOOLS_URL=https://github.com/jlcodes99/cockpit-tools/releases/download/v1.3.81/Cockpit.Tools_1.3.81_amd64.deb
ARG COCKPIT_TOOLS_SHA256=105cf5135d27bd79e9f9ea808a00a0cd7b82c7144c9696bdf550ae8d9137909b
ARG AGENT_BOARD_REF=c63a9e9bf85a7e40a688891b0ac659dc225d9bec
COPY scripts/install-extra-apps.sh /tmp/install-extra-apps.sh
RUN bash /tmp/install-extra-apps.sh && rm /tmp/install-extra-apps.sh
COPY --chmod=755 scripts/start-agent-board.sh /usr/local/bin/agent-board
COPY --chmod=644 desktop/agent-board.desktop /usr/share/applications/agent-board.desktop

# Official Google Antigravity IDE 2.6.0 and standalone agy CLI 1.5.6.
ARG ANTIGRAVITY_IDE_URL=https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.6.0-5526304964083712/linux-x64/Antigravity%20IDE.tar.gz
ARG ANTIGRAVITY_IDE_SHA256=b060a7c7679103b2b619752f8ee7a3088dd241a7d207d4311974b56ea6f94356
ARG ANTIGRAVITY_CLI_URL=https://storage.googleapis.com/antigravity-public/antigravity-cli/1.5.6-6212266538958848/linux-x64/cli_linux_x64.tar.gz
ARG ANTIGRAVITY_CLI_SHA512=0c67824908caf9cc3156699802b8097f2fd02c4608ae9293c9aa7f17e1bcd342c4b9c2e158388253a37804ef6bd9c6b1d25cfaca3c07bbb7587378fc91839bb4
COPY scripts/install-antigravity.sh /tmp/install-antigravity.sh
RUN bash /tmp/install-antigravity.sh && rm /tmp/install-antigravity.sh
COPY --chmod=644 desktop/antigravity-ide.desktop /usr/share/applications/antigravity-ide.desktop

EXPOSE 3000 3001
