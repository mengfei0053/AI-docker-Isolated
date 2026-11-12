#!/usr/bin/env bash
set -euo pipefail

if [[ "$(dpkg --print-architecture)" != amd64 ]]; then
    echo 'These browser packages require Linux amd64.' >&2
    exit 1
fi
mkdir -p /tmp/browser-packages
cd /tmp/browser-packages
curl -fL --retry 3 "$ADSPOWER_URL" -o adspower.deb
curl -fL --retry 3 "$VIRTUAL_BROWSER_URL" -o virtual-browser.deb
curl -fL --retry 3 "$ANT_BROWSER_URL" -o ant-browser.zip
# The official Ant ZIP includes its Debian package as well as a tarball.
unzip -j ant-browser.zip '*.deb'
for package in ./*.deb; do
    [[ "$(dpkg-deb -f "$package" Architecture)" == amd64 ]]
done
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ./*.deb
rm -rf /var/lib/apt/lists/* /tmp/browser-packages
