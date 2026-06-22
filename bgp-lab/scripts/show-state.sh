#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

for router in "${ROUTERS[@]}"; do
  if ! docker_cmd inspect "$(container_name "${router}")" >/dev/null 2>&1; then
    echo "Container $(container_name "${router}") is not present; skipping." >&2
    continue
  fi
  echo
  echo "################################################################"
  echo "Router: ${router}"
  echo "===== ${router}: BGP summary ====="
  vtysh_on "${router}" "show bgp summary" || true
  echo "===== ${router}: BGP routes (kernel) ====="
  vtysh_on "${router}" "show ip route bgp" || true
  echo "===== ${router}: addresses and routes ====="
  run_on "${router}" ip -br address || true
  run_on "${router}" ip route || true
done
