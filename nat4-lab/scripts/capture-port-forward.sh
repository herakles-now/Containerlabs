#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
capture_pair forward-gw "host 10.10.3.10 and tcp port 80" "host 198.51.102.1 and tcp port 8080" "${DURATION:-30}" generate_forward_traffic "./lab.sh test-forward"
