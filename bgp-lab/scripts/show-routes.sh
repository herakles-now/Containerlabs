#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

for router in "${ROUTERS[@]}"; do
  echo
  echo "===== ${router} ====="
  vtysh_on "${router}" \
    "show bgp summary" \
    "show bgp ipv4 unicast" \
    "show ip route bgp"
done
