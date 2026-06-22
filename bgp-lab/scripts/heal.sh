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

echo "Restoring the known-good configuration..."
# configure.sh is idempotent: it restores remote-as, re-announces networks and
# re-applies addresses/forwarding.
"${SCRIPT_DIR}/configure.sh" >/dev/null

# configure.sh does not clear an administrative shutdown, so lift it on the
# peers a fault may have touched.
vtysh_on r1 "configure terminal" "router bgp 100" \
  "no neighbor 192.168.13.2 shutdown" "no neighbor 192.168.12.2 shutdown" "end" >/dev/null 2>&1 || true

reveal_fault
echo "bgp-lab restored. Run './lab.sh bgp verify' to confirm."
