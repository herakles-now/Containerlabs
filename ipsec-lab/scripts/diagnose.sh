#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=../../scripts/diagnose-driver.sh
source "${PROJECT_DIR}/../scripts/diagnose-driver.sh"

require_command docker

check_containers() {
  local n status=0
  for n in "${NODES[@]}"; do
    if [[ "$(docker_cmd inspect -f '{{.State.Running}}' "$(container_name "${n}")" 2>/dev/null)" != "true" ]]; then
      echo "         ${n} is not running"; status=1
    fi
  done
  return "${status}"
}

check_routes() {
  local status=0
  if ! run_on r1 ip route show default 2>/dev/null | grep -q 'via 100.64.1.2'; then
    echo "         R1 has no default route towards the transit (100.64.1.2)"; status=1
  fi
  return "${status}"
}

check_forwarding() {
  local n status=0
  for n in r1 r2 transit; do
    if [[ "$(run_on "${n}" cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" != "1" ]]; then
      echo "         ${n}: IPv4 forwarding disabled"; status=1
    fi
  done
  return "${status}"
}

check_ipsec() {
  local n status=0 sas xfrm
  for n in r1 r2; do
    sas="$(run_on "${n}" swanctl --list-sas 2>/dev/null)"
    if ! grep -q 'ESTABLISHED' <<<"${sas}"; then
      echo "         ${n}: no ESTABLISHED IKE SA"; status=1
    fi
    xfrm="$(run_on "${n}" ip xfrm state 2>/dev/null)"
    if ! grep -q 'proto esp' <<<"${xfrm}"; then
      echo "         ${n}: no ESP entry in the kernel XFRM state"; status=1
    fi
  done
  return "${status}"
}

check_datapath() {
  if run_on pc1 ping -c 2 -W 2 10.2.0.10 >/dev/null 2>&1; then
    return 0
  fi
  echo "         PC1 cannot reach PC2 (10.2.0.10) through the tunnel"
  return 1
}

CHECKS=(
  "Containers running|A node is down — deploy or restart the lab.|check_containers"
  "Addresses & routes|R1 cannot reach the transit; check its default route via 100.64.1.2.|check_routes"
  "IPv4 forwarding|A gateway/transit will not forward packets; check net.ipv4.ip_forward.|check_forwarding"
  "IKE & ESP|The tunnel is not up; check 'swanctl --list-sas' (IKE blocked or auth failing) and 'ip xfrm state'.|check_ipsec"
  "Data path|The SA is up but data fails — suspect ESP being dropped in transit; watch with './lab.sh ipsec transit-watch'.|check_datapath"
)

run_diagnosis
