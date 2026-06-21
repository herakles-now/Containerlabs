#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command containerlab
require_root

if containerlab inspect --topo "${TOPOLOGY_FILE}" >/dev/null 2>&1; then
  containerlab destroy --topo "${TOPOLOGY_FILE}" --cleanup
else
  echo "Lab ${LAB_NAME} is not deployed. Nothing to destroy."
fi
