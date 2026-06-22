#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

clab_overview

echo
echo "################################################################"
echo "Per-router state"
"${SCRIPT_DIR}/show-state.sh"
