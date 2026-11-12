FROM ghcr.io/xjasonlyu/tun2socks:v2.5.2
RUN apk add --no-cache bash iproute2 iptables curl python3 && \
    ln -sf /sbin/xtables-nft-multi /sbin/iptables && \
    ln -sf /sbin/xtables-nft-multi /sbin/iptables-save && \
    ln -sf /sbin/xtables-nft-multi /sbin/iptables-restore && \
    ln -sf /usr/bin/tun2socks /usr/local/bin/tun2socks
COPY proxy-init.sh /usr/local/bin/proxy-init.sh
COPY gateway/dns-forwarder.py /usr/local/bin/dns-forwarder.py
RUN chmod +x /usr/local/bin/proxy-init.sh
ENTRYPOINT ["/usr/local/bin/proxy-init.sh"]
