#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
capture_pair dynamic-gw "net 10.10.2.0/24" "net 198.51.101.0/24" "${DURATION:-30}"
