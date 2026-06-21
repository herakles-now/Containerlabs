#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker
require_nodes "${CONTAINERS[@]}"

# Static NAT
set_address static-host eth1 10.10.1.10/24
set_default_route static-host 10.10.1.1
set_address static-gw eth1 10.10.1.1/24
set_address static-gw eth2 198.51.100.1/24
set_address static-gw eth2 198.51.100.10/32
enable_gateway static-gw
set_address static-server eth1 198.51.100.100/24
set_default_route static-server 198.51.100.1

# Dynamic pool NAT
set_address dynamic-host1 eth1 10.10.2.10/24
set_default_route dynamic-host1 10.10.2.1
set_address dynamic-host2 eth1 10.10.2.11/24
set_default_route dynamic-host2 10.10.2.1
set_address dynamic-gw eth1 10.10.2.1/24
set_address dynamic-gw eth2 198.51.101.1/24
for last_octet in {10..20}; do
  set_address dynamic-gw eth2 "198.51.101.${last_octet}/32"
done
enable_gateway dynamic-gw
set_address dynamic-server eth1 198.51.101.100/24
set_default_route dynamic-server 198.51.101.1

# Static port forwarding
set_address forward-server eth1 10.10.3.10/24
set_default_route forward-server 10.10.3.1
set_address forward-gw eth1 10.10.3.1/24
set_address forward-gw eth2 198.51.102.1/24
enable_gateway forward-gw
set_address forward-client eth1 198.51.102.100/24
set_default_route forward-client 198.51.102.1

# Dynamic port NAT / PAT
set_address pat-host1 eth1 10.10.4.10/24
set_default_route pat-host1 10.10.4.1
set_address pat-host2 eth1 10.10.4.11/24
set_default_route pat-host2 10.10.4.1
set_address pat-gw eth1 10.10.4.1/24
set_address pat-gw eth2 198.51.103.1/24
enable_gateway pat-gw
set_address pat-server eth1 198.51.103.100/24
set_default_route pat-server 198.51.103.1

"${SCRIPT_DIR}/configure-static-nat.sh"
"${SCRIPT_DIR}/configure-dynamic-nat.sh"
"${SCRIPT_DIR}/configure-port-forward.sh"
"${SCRIPT_DIR}/configure-pat.sh"

echo "All four NAT scenarios are configured."
