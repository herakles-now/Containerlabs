#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command ip
ensure_sudo

for bridge in "${BRIDGES[@]}"; do
  if ip link show "${bridge}" >/dev/null 2>&1; then
    echo "Bridge ${bridge} already exists."
  else
    as_root ip link add name "${bridge}" type bridge
    echo "Created bridge ${bridge}."
  fi
  as_root ip link set "${bridge}" up
done
