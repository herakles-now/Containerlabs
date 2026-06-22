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
# configure-all.sh is idempotent: it re-adds addresses, routes, the nft tables,
# re-enables ip_forward and resets all/default rp_filter.
"${SCRIPT_DIR}/configure-all.sh" >/dev/null

# A fault may have set per-interface rp_filter, which configure-all does not
# touch; clear it on every gateway interface.
for gw in static-gw dynamic-gw forward-gw pat-gw; do
  # $f is expanded by the container's shell, not here, so single quotes stay.
  # shellcheck disable=SC2016
  run_on "${gw}" sh -c 'for f in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 0 > "$f"; done' >/dev/null 2>&1 || true
done

reveal_fault
echo "nat4-lab restored. Run './lab.sh nat4 verify' to confirm."
