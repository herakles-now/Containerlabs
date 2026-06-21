#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command ip
require_root

for bridge in "${BRIDGES[@]}"; do
  if ip link show "${bridge}" >/dev/null 2>&1; then
    echo "Bridge ${bridge} already exists."
  else
    ip link add name "${bridge}" type bridge
    echo "Created bridge ${bridge}."
  fi
  ip link set "${bridge}" up
done
