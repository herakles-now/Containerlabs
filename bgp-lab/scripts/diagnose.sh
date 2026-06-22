#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=../../scripts/diagnose-driver.sh
source "${PROJECT_DIR}/../scripts/diagnose-driver.sh"

require_command docker

check_containers() {
  local r status=0
  for r in "${ROUTERS[@]}"; do
    if [[ "$(docker_cmd inspect -f '{{.State.Running}}' "$(container_name "${r}")" 2>/dev/null)" != "true" ]]; then
      echo "         ${r} is not running"; status=1
    fi
  done
  return "${status}"
}

check_interfaces() {
  local r status=0
  for r in "${ROUTERS[@]}"; do
    if ! run_on "${r}" ip -br address show dummy0 2>/dev/null | grep -q '10\.'; then
      echo "         ${r}: dummy0 has no 10.x address"; status=1
    fi
  done
  return "${status}"
}

check_forwarding() {
  local r status=0
  for r in "${ROUTERS[@]}"; do
    if [[ "$(run_on "${r}" cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" != "1" ]]; then
      echo "         ${r}: IPv4 forwarding disabled"; status=1
    fi
  done
  return "${status}"
}

check_sessions() {
  local r status=0 summary
  for r in "${ROUTERS[@]}"; do
    summary="$(vtysh_on "${r}" "show bgp summary" 2>/dev/null)"
    if grep -qE '(Idle|Active|Connect|OpenSent|OpenConfirm)' <<<"${summary}"; then
      echo "         ${r}: a neighbor is not Established"; status=1
    fi
  done
  return "${status}"
}

check_prefixes() {
  local r p table status=0
  # Every router should learn all seven /16s (one router per AS, full
  # propagation). Check each router's table, not just R1.
  for r in "${ROUTERS[@]}"; do
    table="$(vtysh_on "${r}" "show bgp ipv4 unicast" 2>/dev/null)"
    for p in 10.1.0.0/16 10.2.0.0/16 10.3.0.0/16 10.4.0.0/16 10.5.0.0/16 10.6.0.0/16 10.7.0.0/16; do
      if ! grep -Fq "${p}" <<<"${table}"; then
        echo "         ${r} is missing ${p} in its BGP table"; status=1
      fi
    done
  done
  return "${status}"
}

check_datapath() {
  local status=0
  # A few sourced pings across different AS-path lengths, not just R1->R7.
  run_on r1 ping -c 2 -W 2 -I 10.1.0.1 10.7.0.1 >/dev/null 2>&1 || { echo "         R1 (10.1.0.1) cannot reach R7 (10.7.0.1)"; status=1; }
  run_on r2 ping -c 2 -W 2 -I 10.2.0.1 10.6.0.1 >/dev/null 2>&1 || { echo "         R2 (10.2.0.1) cannot reach R6 (10.6.0.1)"; status=1; }
  run_on r4 ping -c 2 -W 2 -I 10.5.0.1 10.1.0.1 >/dev/null 2>&1 || { echo "         R4 (10.5.0.1) cannot reach R1 (10.1.0.1)"; status=1; }
  return "${status}"
}

CHECKS=(
  "Containers running|Some routers are down — deploy or restart the lab.|check_containers"
  "Interfaces & addresses|A router lost its dummy0 address — re-run './lab.sh bgp configure'.|check_interfaces"
  "IPv4 forwarding|A router will not forward transit traffic; check net.ipv4.ip_forward.|check_forwarding"
  "BGP sessions|A neighbor is down; in 'show bgp summary' look for Idle/Active and check remote-as plus 'no neighbor ... shutdown'.|check_sessions"
  "Prefix origination|R1 is missing prefixes; check that each origin router still has its 'network' statement.|check_prefixes"
  "Data path|Control plane looks fine but forwarding fails; check 'show ip route bgp', kernel routes and the reverse path.|check_datapath"
)

run_diagnosis
