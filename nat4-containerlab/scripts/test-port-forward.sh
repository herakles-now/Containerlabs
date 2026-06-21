#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_nodes forward-client forward-gw forward-server
"${SCRIPT_DIR}/configure-port-forward.sh"
start_http_server forward-server 80 "inside server reached through port forwarding"
capture_for_test forward-gw "tcp port 80 or tcp port 8080" port-forward 6

echo "Generating: outside client -> 198.51.102.1:8080"
response="$(run_on forward-client curl -fsS --max-time 4 http://198.51.102.1:8080/)"
finish_test_capture

if [[ "${response}" != *"inside server reached through port forwarding"* ]]; then
  echo "ERROR: Port-forwarded HTTP response was not received." >&2
  exit 1
fi
if ! grep -Eq '198\.51\.102\.100\.[0-9]+ > 198\.51\.102\.1\.8080' <<<"${CAPTURE_OUTSIDE_OUTPUT}"; then
  echo "ERROR: The public destination tuple was not captured." >&2
  exit 1
fi
if ! grep -Eq '198\.51\.102\.100\.[0-9]+ > 10\.10\.3\.10\.80' <<<"${CAPTURE_INSIDE_OUTPUT}"; then
  echo "ERROR: The translated inside destination tuple was not captured." >&2
  exit 1
fi
echo "Expected interpretation: destination 198.51.102.1:8080 becomes 10.10.3.10:80."
show_gateway_state forward-gw
