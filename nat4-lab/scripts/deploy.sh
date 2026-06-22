#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker
require_command containerlab
require_command ip
ensure_sudo

if ! docker_cmd info >/dev/null 2>&1; then
  echo "ERROR: Docker is installed, but the daemon is unavailable or access is denied." >&2
  exit 1
fi

"${SCRIPT_DIR}/build.sh"

echo "Creating the eight isolated host bridges..."
"${SCRIPT_DIR}/setup-host-bridges.sh"

echo "Deploying ${LAB_NAME}..."
clab deploy --topo "${TOPOLOGY_FILE}"

echo "Configuring addresses, routes, forwarding and nftables..."
"${SCRIPT_DIR}/configure-all.sh"
