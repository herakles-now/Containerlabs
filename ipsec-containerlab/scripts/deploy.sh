#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker
require_command containerlab
require_root

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is unavailable or access to the daemon is denied." >&2
  exit 1
fi

echo "Building ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" "${PROJECT_DIR}"

echo "Deploying ${LAB_NAME}..."
containerlab deploy --topo "${TOPOLOGY_FILE}"

echo "Waiting for IPsec services to initialize..."
sleep 5
"${SCRIPT_DIR}/verify.sh"
