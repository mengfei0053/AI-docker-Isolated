#!/usr/bin/env bash
set -euo pipefail

# This runs ONLY in the gateway, before the desktop is allowed to start.
iptables -P OUTPUT DROP
iptables -F OUTPUT
iptables -A OUTPUT -d 127.0.0.11/32 -j REJECT
iptables -A OUTPUT -o lo -j ACCEPT
# Accept only responses to incoming desktop connections, not new connections.
iptables -A OUTPUT -p tcp -m multiport --sports 3000,3001 \
    -m conntrack --ctstate ESTABLISHED -j ACCEPT
[[ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == 1 ]]

PROXY_HOST="${PROXY_HOST:-host.docker.internal}"
PROXY_PORT="${PROXY_PORT:-10810}"
PROXY_IP=$(getent ahostsv4 "$PROXY_HOST" | awk 'NR == 1 {print $1}')
[[ -n "$PROXY_IP" && "$PROXY_PORT" =~ ^[0-9]+$ ]]
DEFAULT_GW=$(ip -4 route show default | awk 'NR == 1 {print $3}')
DEFAULT_DEV=$(ip -4 route show default | awk 'NR == 1 {print $5}')
[[ -n "$DEFAULT_GW" && -n "$DEFAULT_DEV" ]]

# Keep the requested private LAN exceptions. DNS port 53 is handled separately.
iptables -A OUTPUT -o "$DEFAULT_DEV" -p tcp -d "$PROXY_IP" \
    --dport "$PROXY_PORT" -j ACCEPT
for subnet in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    ip route replace "$subnet" via "$DEFAULT_GW" dev "$DEFAULT_DEV"
    iptables -A OUTPUT -o "$DEFAULT_DEV" -d "$subnet" -j ACCEPT
done
ip route replace "$PROXY_IP/32" via "$DEFAULT_GW" dev "$DEFAULT_DEV"

# Intercept normal DNS before Docker's embedded DNS NAT rules can forward it.
for protocol in udp tcp; do
    while iptables -t nat -D OUTPUT -p "$protocol" --dport 53 \
        -m mark ! --mark 53 -j DNAT --to-destination 127.0.0.1:1053 \
        2>/dev/null; do :; done
    iptables -t nat -I OUTPUT 1 -p "$protocol" --dport 53 -m mark ! --mark 53 \
        -j DNAT --to-destination 127.0.0.1:1053
done

ip link delete tun0 2>/dev/null || true
ip tuntap add mode tun dev tun0
ip addr add 198.18.0.1/15 dev tun0
ip link set tun0 up
ip route replace 0.0.0.0/1 dev tun0
ip route replace 128.0.0.0/1 dev tun0
iptables -A OUTPUT -o tun0 -j ACCEPT

python3 /usr/local/bin/dns-forwarder.py &
DNS_PID=$!
/usr/local/bin/tun2socks -device tun0 \
    -proxy "socks5://${PROXY_IP}:${PROXY_PORT}" -loglevel warning &
TUN_PID=$!
cleanup() {
    kill "$DNS_PID" "$TUN_PID" 2>/dev/null || true
    wait "$DNS_PID" "$TUN_PID" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT
# If either process dies, exit and let Docker restart the gateway.
# OUTPUT remains DROP and the desktop retains this namespace, not a direct route.
wait -n "$DNS_PID" "$TUN_PID"
exit 1
