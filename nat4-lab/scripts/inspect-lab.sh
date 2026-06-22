#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

CASE="${CASE:-all}"

print_case_overview() {
  local case_name="$1" gateway="$2" path_text="$3"

  echo
  echo "################################################################"
  echo "Scenario: ${case_name}"
  echo "Path: ${path_text}"
  echo "Gateway: ${gateway} (inside: eth1, outside: eth2)"
  echo
  show_gateway_state "${gateway}"
  echo "===== ${gateway}: addresses and routes ====="
  run_on "${gateway}" ip -br address
  run_on "${gateway}" ip route
}

require_nodes static-gw dynamic-gw forward-gw pat-gw

clab_overview

case "${CASE}" in
  static)
    print_case_overview "static" static-gw "static-host -> static-gw -> static-server"
    ;;
  dynamic)
    print_case_overview "dynamic" dynamic-gw "dynamic-host1|dynamic-host2 -> dynamic-gw -> dynamic-server"
    ;;
  forward)
    print_case_overview "forward" forward-gw "forward-client -> forward-gw -> forward-server"
    ;;
  pat)
    print_case_overview "pat" pat-gw "pat-host1|pat-host2 -> pat-gw -> pat-server"
    ;;
  all)
    print_case_overview "static" static-gw "static-host -> static-gw -> static-server"
    print_case_overview "dynamic" dynamic-gw "dynamic-host1|dynamic-host2 -> dynamic-gw -> dynamic-server"
    print_case_overview "forward" forward-gw "forward-client -> forward-gw -> forward-server"
    print_case_overview "pat" pat-gw "pat-host1|pat-host2 -> pat-gw -> pat-server"
    ;;
  *)
    echo "ERROR: CASE must be static, dynamic, forward, pat, or all." >&2
    exit 2
    ;;
esac
