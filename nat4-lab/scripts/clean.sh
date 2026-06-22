#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

"${SCRIPT_DIR}/destroy.sh"

echo "Removing image ${IMAGE_NAME}..."
docker_cmd image rm "${IMAGE_NAME}" >/dev/null 2>&1 || true
