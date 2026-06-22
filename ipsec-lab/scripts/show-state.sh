#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

# IPsec state lives on the two gateways; the PCs and the transit only carry
# addresses and routes.
for node in r1 r2; do
  if ! docker_cmd inspect "$(container_name "${node}")" >/dev/null 2>&1; then
    echo "Container $(container_name "${node}") is not present; skipping." >&2
    continue
  fi
  echo
  echo "################################################################"
  echo "Gateway: ${node}"
  echo "===== ${node}: IKE/CHILD security associations ====="
  run_on "${node}" swanctl --list-sas || true
  echo "===== ${node}: loaded connections ====="
  run_on "${node}" swanctl --list-conns || true
  echo "===== ${node}: kernel XFRM state ====="
  run_on "${node}" ip xfrm state || true
  echo "===== ${node}: kernel XFRM policy ====="
  run_on "${node}" ip xfrm policy || true
  echo "===== ${node}: addresses and routes ====="
  run_on "${node}" ip -br address || true
  run_on "${node}" ip route || true
done
