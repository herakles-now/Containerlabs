#!/usr/bin/env bash
set -euo pipefail

ip addr flush dev eth1
ip link set eth1 up
ip addr add 10.1.0.10/24 dev eth1
ip route replace default via 10.1.0.1 dev eth1

ip -br addr
ip route
