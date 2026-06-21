#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

# Sequence 10 changes only R5's prefix. Sequence 20 explicitly permits every
# other route from R3 without changing its attributes.
vtysh_on r1 \
  "configure terminal" \
  "ip prefix-list R5-NET seq 10 permit 10.3.0.0/16" \
  "route-map PREFER-R3-FOR-R5 permit 10" \
  "match ip address prefix-list R5-NET" \
  "set local-preference 200" \
  "route-map PREFER-R3-FOR-R5 permit 20" \
  "router bgp 100" \
  "address-family ipv4 unicast" \
  "neighbor 192.168.13.2 route-map PREFER-R3-FOR-R5 in" \
  "exit-address-family" \
  "end" \
  "write memory" \
  "clear bgp ipv4 unicast 192.168.13.2 soft in" >/dev/null

# Route refresh is asynchronous; allow FRR to replace the temporarily stale paths.
sleep 2
echo "R1 now prefers R3 for 10.3.0.0/16:"
vtysh_on r1 "show bgp ipv4 unicast 10.3.0.0/16"
