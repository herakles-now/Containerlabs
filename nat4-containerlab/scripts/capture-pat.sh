#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
capture_pair pat-gw "net 10.10.4.0/24" "host 198.51.103.1" "${DURATION:-30}"
