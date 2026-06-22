#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=faults.sh
source "${SCRIPT_DIR}/faults.sh"
# shellcheck source=../../scripts/fault-driver.sh
source "${PROJECT_DIR}/../scripts/fault-driver.sh"

require_command docker
if ! docker_cmd inspect "$(container_name r1)" >/dev/null 2>&1; then
  echo "The ${LAB_NAME} is not deployed. Run './lab.sh ${LAB_SHORT} deploy' first." >&2
  exit 1
fi

run_break
