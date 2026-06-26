#!/usr/bin/env bash
set -euo pipefail

# L2 switch for the cluster subnet: put the three data-plane links into one
# Linux bridge so pg1, pg2 and pg3 share a single broadcast domain. Bringing a
# bridge port down later is how the lab simulates a network partition.

# The links may take a moment to appear after the container starts.
for _ in $(seq 1 40); do
  [[ -e /sys/class/net/eth1 && -e /sys/class/net/eth2 && -e /sys/class/net/eth3 && -e /sys/class/net/eth4 ]] && break
  sleep 0.25
done

ip link add name br0 type bridge 2>/dev/null || true
ip link set br0 up
for i in eth1 eth2 eth3 eth4; do
  ip link set "${i}" up
  ip link set "${i}" master br0
done

ip -br link
