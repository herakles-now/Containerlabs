#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_nodes dynamic-host1 dynamic-host2 dynamic-gw dynamic-server
"${SCRIPT_DIR}/configure-dynamic-nat.sh"
start_http_server dynamic-server 80 "dynamic NAT outside server"
capture_for_test dynamic-gw "tcp port 80" dynamic-nat 7

echo "Generating two flows with the same original source port 42000."
run_on dynamic-host1 sh -c "printf 'GET / HTTP/1.0\\r\\nHost: dynamic1\\r\\n\\r\\n' | nc -p 42000 -w 3 198.51.101.100 80" >/dev/null &
pid1=$!
run_on dynamic-host2 sh -c "printf 'GET / HTTP/1.0\\r\\nHost: dynamic2\\r\\n\\r\\n' | nc -p 42000 -w 3 198.51.101.100 80" >/dev/null &
pid2=$!
wait "${pid1}"
wait "${pid2}"
finish_test_capture

if ! grep -Eq '10\.10\.2\.10\.42000 > 198\.51\.101\.100\.80' <<<"${CAPTURE_INSIDE_OUTPUT}" ||
   ! grep -Eq '10\.10\.2\.11\.42000 > 198\.51\.101\.100\.80' <<<"${CAPTURE_INSIDE_OUTPUT}"; then
  echo "ERROR: Both original dynamic-NAT flows were not captured." >&2
  exit 1
fi
pool_ip_count="$({ grep -Eo '198\.51\.101\.(1[0-9]|20)\.42000 > 198\.51\.101\.100\.80' <<<"${CAPTURE_OUTSIDE_OUTPUT}" || true; } | cut -d. -f1-4 | sort -u | wc -l)"
if (( pool_ip_count < 2 )); then
  echo "ERROR: Expected two distinct public pool addresses, found ${pool_ip_count}." >&2
  exit 1
fi
echo "Expected interpretation: each host receives a pool IP; source port 42000 is normally preserved."
echo "Conntrack may translate a port if a tuple collision requires it."
show_gateway_state dynamic-gw
