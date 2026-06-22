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
# Flush any injected iptables drop rules and re-enable forwarding everywhere.
# The lab does not use iptables itself, so flushing is safe.
for node in r1 r2 transit; do
  run_on "${node}" iptables -F >/dev/null 2>&1 || true
  run_on "${node}" sysctl -q -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
done

# Restore R1's default route towards the transit.
run_on r1 ip route replace default via 100.64.1.2 dev eth2 >/dev/null 2>&1 || true

# Reload the mounted swanctl config and re-establish the tunnel.
run_on r1 swanctl --load-all >/dev/null 2>&1 || true
run_on r2 swanctl --load-all >/dev/null 2>&1 || true
run_on r1 swanctl --terminate --ike r1-r2 >/dev/null 2>&1 || true
run_on r1 swanctl --initiate --child lan-to-lan >/dev/null 2>&1 || true

reveal_fault
echo "ipsec-lab restored. Run './lab.sh ipsec verify' to confirm."
