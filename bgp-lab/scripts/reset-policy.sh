#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

vtysh_on r1 \
  "configure terminal" \
  "router bgp 100" \
  "address-family ipv4 unicast" \
  "no neighbor 192.168.13.2 route-map PREFER-R3-FOR-R5 in" \
  "exit-address-family" \
  "exit" \
  "no route-map PREFER-R3-FOR-R5" \
  "no ip prefix-list R5-NET" \
  "end" \
  "write memory" \
  "clear bgp ipv4 unicast 192.168.13.2 soft in" >/dev/null

# Route refresh is asynchronous; allow FRR to replace the temporarily stale paths.
sleep 2
echo "The R1 Local Preference policy has been removed:"
vtysh_on r1 "show bgp ipv4 unicast 10.3.0.0/16"
