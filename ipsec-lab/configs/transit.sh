#!/usr/bin/env bash
set -euo pipefail

ip addr flush dev eth1
ip addr flush dev eth2
ip link set eth1 up
ip link set eth2 up
ip addr add 100.64.1.2/30 dev eth1
ip addr add 100.64.2.1/30 dev eth2

sysctl -w net.ipv4.ip_forward=1
for scope in all default eth1 eth2; do
  sysctl -w "net.ipv4.conf.${scope}.rp_filter=0"
done

# Intentionally no routes to 10.1.0.0/24 or 10.2.0.0/24.
mkdir -p /var/log/ipsec-lab
chmod +x /root/transit-log.sh
nohup /root/transit-log.sh >/proc/1/fd/1 2>&1 &
echo "Transit log: /var/log/ipsec-lab/transit.log"

ip -br addr
ip route
