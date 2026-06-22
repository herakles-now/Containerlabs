#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker
ensure_sudo

if ! docker_cmd info >/dev/null 2>&1; then
  echo "ERROR: Docker is installed, but the daemon is unavailable or access is denied." >&2
  exit 1
fi

echo "Building ${IMAGE_NAME}..."
docker_cmd build -t "${IMAGE_NAME}" "${PROJECT_DIR}"
