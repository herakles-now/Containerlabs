#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_nodes static-gw dynamic-gw forward-gw pat-gw
for gateway in static-gw dynamic-gw forward-gw pat-gw; do
  echo
  echo "################################################################"
  show_gateway_state "${gateway}"
  echo "===== ${gateway}: addresses and routes ====="
  run_on "${gateway}" ip -br address
  run_on "${gateway}" ip route
done
