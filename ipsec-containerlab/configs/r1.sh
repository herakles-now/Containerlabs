#!/usr/bin/env bash
set -euo pipefail

ip addr flush dev eth1
ip addr flush dev eth2
ip link set eth1 up
ip link set eth2 up
ip addr add 10.1.0.1/24 dev eth1
ip addr add 100.64.1.1/30 dev eth2
ip route replace default via 100.64.1.2 dev eth2

sysctl -w net.ipv4.ip_forward=1
for scope in all default eth1 eth2; do
  sysctl -w "net.ipv4.conf.${scope}.rp_filter=0"
done

ipsec start
for _ in $(seq 1 20); do
  [[ -S /var/run/charon.vici ]] && break
  sleep 0.25
done
[[ -S /var/run/charon.vici ]] || { echo "Error: charon.vici was not created" >&2; exit 1; }
swanctl --load-all
swanctl --list-conns

ip -br addr
ip route
