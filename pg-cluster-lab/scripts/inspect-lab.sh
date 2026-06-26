#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

clab_overview

echo
echo "################################################################"
echo "Per-node addresses"
for node in "${NODES[@]}"; do
  if ! docker_cmd inspect "$(container_name "${node}")" >/dev/null 2>&1; then
    echo "Container $(container_name "${node}") is not present; skipping." >&2
    continue
  fi
  echo
  echo "===== ${node}: addresses ====="
  run_on "${node}" ip -br address || true
done

echo
echo "################################################################"
echo "PostgreSQL cluster state"
"${SCRIPT_DIR}/show-state.sh"
