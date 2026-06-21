#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_nodes pat-host1 pat-host2 pat-gw pat-server
"${SCRIPT_DIR}/configure-pat.sh"
start_http_server pat-server 80 "PAT outside server"
capture_for_test pat-gw "tcp port 80" pat 7

echo "Generating simultaneous flows from both hosts with source port 43000."
run_on pat-host1 sh -c "printf 'GET / HTTP/1.0\\r\\nHost: pat1\\r\\n\\r\\n' | nc -p 43000 -w 4 198.51.103.100 80" >/dev/null &
pid1=$!
run_on pat-host2 sh -c "printf 'GET / HTTP/1.0\\r\\nHost: pat2\\r\\n\\r\\n' | nc -p 43000 -w 4 198.51.103.100 80" >/dev/null &
pid2=$!
wait "${pid1}"
wait "${pid2}"
finish_test_capture

if ! grep -Eq '10\.10\.4\.10\.43000 > 198\.51\.103\.100\.80' <<<"${CAPTURE_INSIDE_OUTPUT}" ||
   ! grep -Eq '10\.10\.4\.11\.43000 > 198\.51\.103\.100\.80' <<<"${CAPTURE_INSIDE_OUTPUT}"; then
  echo "ERROR: Both original PAT flows were not captured." >&2
  exit 1
fi
translated_port_count="$({ grep -Eo '198\.51\.103\.1\.[0-9]+ > 198\.51\.103\.100\.80' <<<"${CAPTURE_OUTSIDE_OUTPUT}" || true; } | sed -E 's/^198\.51\.103\.1\.([0-9]+).*/\1/' | sort -u | wc -l)"
if (( translated_port_count < 2 )); then
  echo "ERROR: PAT did not produce two distinguishable outside source ports." >&2
  exit 1
fi
echo "Expected interpretation: both flows use 198.51.103.1; conntrack changes at least one source port."
show_gateway_state pat-gw
