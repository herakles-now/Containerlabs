#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command ip
require_root

for bridge in "${BRIDGES[@]}"; do
  if ip link show "${bridge}" >/dev/null 2>&1; then
    ip link delete "${bridge}" type bridge
    echo "Removed bridge ${bridge}."
  fi
done
