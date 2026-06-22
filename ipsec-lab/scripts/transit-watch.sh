#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker
require_container transit

echo "Following the transit capture (UDP/500 IKE, ESP, ICMP). Press Ctrl-C to stop."
echo "Trigger traffic from another terminal, e.g.:"
echo "  ./lab.sh verify   or   docker exec -it $(container_name pc1) ping -c5 10.2.0.10"
echo
run_on transit tail -f -n +1 /var/log/ipsec-lab/transit.log
