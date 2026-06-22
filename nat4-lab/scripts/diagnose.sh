#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=../../scripts/diagnose-driver.sh
source "${PROJECT_DIR}/../scripts/diagnose-driver.sh"

require_command docker

GATEWAYS=(static-gw dynamic-gw forward-gw pat-gw)

check_containers() {
  local c status=0
  for c in "${CONTAINERS[@]}"; do
    if [[ "$(docker_cmd inspect -f '{{.State.Running}}' "$(container_name "${c}")" 2>/dev/null)" != "true" ]]; then
      echo "         ${c} is not running"; status=1
    fi
  done
  return "${status}"
}

check_sysctls() {
  local gw status=0
  for gw in "${GATEWAYS[@]}"; do
    if [[ "$(run_on "${gw}" cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" != "1" ]]; then
      echo "         ${gw}: IPv4 forwarding disabled"; status=1
    fi
    if [[ "$(run_on "${gw}" cat /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null)" != "0" ]]; then
      echo "         ${gw}: strict rp_filter (conf.all) is enabled"; status=1
    fi
  done
  return "${status}"
}

check_nat() {
  local gw status=0
  for gw in "${GATEWAYS[@]}"; do
    if ! run_on "${gw}" nft list table ip nat4 >/dev/null 2>&1; then
      echo "         ${gw}: no 'ip nat4' table"; status=1
    fi
  done
  return "${status}"
}

check_datapath() {
  local status=0
  run_on static-host ping -c 2 -W 2 198.51.100.100 >/dev/null 2>&1 || { echo "         static-host cannot reach 198.51.100.100"; status=1; }
  run_on dynamic-host1 ping -c 2 -W 2 198.51.101.100 >/dev/null 2>&1 || { echo "         dynamic-host1 cannot reach 198.51.101.100"; status=1; }
  run_on pat-host1 ping -c 2 -W 2 198.51.103.100 >/dev/null 2>&1 || { echo "         pat-host1 cannot reach 198.51.103.100"; status=1; }
  return "${status}"
}

CHECKS=(
  "Containers running|A node is down — deploy or restart the lab.|check_containers"
  "Gateway sysctls|A gateway will not route or drops return traffic; check net.ipv4.ip_forward and conf.all.rp_filter.|check_sysctls"
  "NAT tables|A gateway lost its 'ip nat4' table — re-run './lab.sh nat4 configure'.|check_nat"
  "Data path|Inside hosts cannot reach their outside server (static/dynamic/pat); inspect nft rules and conntrack with './lab.sh nat4 state'.|check_datapath"
)

run_diagnosis
