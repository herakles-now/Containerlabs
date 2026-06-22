#!/usr/bin/env bash
set -euo pipefail

# Host-side follower for the transit "Internet" capture. The capture itself is
# produced inside the transit container by transit-log.sh (mounted via the
# topology and started by configs/transit.sh); this script just tails that log
# with `docker exec`. It optionally pings PC2 from PC1 so traffic appears
# without a second terminal.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker
require_container transit

echo "Following the transit capture (UDP/500 IKE, ESP, ICMP). Press Ctrl-C to stop."
if prompt_yes_no "Auto-generate test traffic (ping PC1 -> PC2) once the capture is up?"; then
  echo "Pinging 10.2.0.10 from PC1 in the background; press Ctrl-C to stop watching."
  ( sleep 2; run_on pc1 ping -c "${PINGS:-5}" 10.2.0.10 >/dev/null 2>&1 || true ) &
else
  echo "Trigger traffic from another terminal, e.g.:"
  echo "  ./lab.sh verify   or   docker exec -it $(container_name pc1) ping -c5 10.2.0.10"
fi
echo
run_on transit tail -f -n +1 /var/log/ipsec-lab/transit.log
