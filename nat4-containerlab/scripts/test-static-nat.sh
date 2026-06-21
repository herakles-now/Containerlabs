#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_nodes static-host static-gw static-server
"${SCRIPT_DIR}/configure-static-nat.sh"
start_http_server static-server 80 "static NAT outside server"
capture_for_test static-gw "tcp port 80" static-nat 6

echo "Generating: 10.10.1.10:41000 -> 198.51.100.100:80"
run_on static-host sh -c "printf 'GET / HTTP/1.0\\r\\nHost: static\\r\\n\\r\\n' | nc -p 41000 -w 3 198.51.100.100 80" >/dev/null
finish_test_capture

if ! grep -Eq '10\.10\.1\.10\.41000 > 198\.51\.100\.100\.80' <<<"${CAPTURE_INSIDE_OUTPUT}"; then
  echo "ERROR: The expected pre-NAT tuple was not captured." >&2
  exit 1
fi
if ! grep -Eq '198\.51\.100\.10\.41000 > 198\.51\.100\.100\.80' <<<"${CAPTURE_OUTSIDE_OUTPUT}"; then
  echo "ERROR: Static SNAT did not preserve source port 41000 as expected." >&2
  exit 1
fi
echo "Expected interpretation: only the source IP changes; TCP source port 41000 remains 41000."
show_gateway_state static-gw
