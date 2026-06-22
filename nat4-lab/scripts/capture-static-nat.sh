#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
capture_pair static-gw "net 10.10.1.0/24 or host 198.51.100.100" "host 198.51.100.10 or host 198.51.100.100" "${DURATION:-30}" generate_static_traffic "./lab.sh test-static"
