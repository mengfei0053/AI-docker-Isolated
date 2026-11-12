#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose exec -T webtop bash -s <<'TEST'
set -euo pipefail
[[ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == 1 ]]
if iptables -P OUTPUT ACCEPT 2>/dev/null; then
    echo 'FAIL: desktop can change firewall' >&2
    exit 1
fi
# Name resolution and HTTPS must succeed with the proxy available.
curl -fsS --max-time 25 --noproxy '*' https://example.com >/dev/null
# An interface-bound request must not reach a public address directly.
if curl -kfsS --max-time 8 --noproxy '*' --interface eth0 \
    https://1.1.1.1 >/dev/null 2>&1; then
    echo 'FAIL: direct public IPv4 connection succeeded' >&2
    exit 1
fi
if curl -gkfsS --max-time 8 --noproxy '*' \
    'https://[2606:4700:4700::1111]' >/dev/null 2>&1; then
    echo 'FAIL: public IPv6 connection succeeded' >&2
    exit 1
fi
echo 'PASS: proxy HTTPS, desktop permissions, direct IPv4/IPv6 blocking'
TEST

# Simulate proxy outage without stopping the host proxy or other services.
# Only this gateway's TCP access to 10810 is blocked temporarily.
cleanup() {
    docker compose exec -T proxy-gateway iptables -D OUTPUT \
        -p tcp --dport 10810 -j REJECT >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker compose exec -T proxy-gateway iptables -I OUTPUT 1 \
    -p tcp --dport 10810 -j REJECT
if docker compose exec -T webtop curl -kfsS --max-time 10 \
    --noproxy '*' https://1.1.1.1 >/dev/null 2>&1; then
    echo 'FAIL: public traffic succeeded with proxy blocked' >&2
    exit 1
fi
if timeout 20 docker compose exec -T webtop getent ahostsv4 example.com \
    >/dev/null 2>&1; then
    echo 'FAIL: DNS succeeded with proxy blocked (check caches)' >&2
    exit 1
fi
echo 'PASS: public HTTPS and uncached DNS fail when proxy access is blocked'
