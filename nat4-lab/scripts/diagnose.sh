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

check_mtu() { check_interface_mtu "${CONTAINERS[@]}"; }

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
  # static/dynamic/pat use protocol-agnostic SNAT, so ICMP exercises them.
  # Both hosts behind the dynamic and PAT gateways are checked.
  run_on static-host ping -c 2 -W 2 198.51.100.100 >/dev/null 2>&1 || { echo "         static-host cannot reach 198.51.100.100"; status=1; }
  run_on dynamic-host1 ping -c 2 -W 2 198.51.101.100 >/dev/null 2>&1 || { echo "         dynamic-host1 cannot reach 198.51.101.100"; status=1; }
  run_on dynamic-host2 ping -c 2 -W 2 198.51.101.100 >/dev/null 2>&1 || { echo "         dynamic-host2 cannot reach 198.51.101.100"; status=1; }
  run_on pat-host1 ping -c 2 -W 2 198.51.103.100 >/dev/null 2>&1 || { echo "         pat-host1 cannot reach 198.51.103.100"; status=1; }
  run_on pat-host2 ping -c 2 -W 2 198.51.103.100 >/dev/null 2>&1 || { echo "         pat-host2 cannot reach 198.51.103.100"; status=1; }
  # Port forwarding is TCP-only (DNAT 198.51.102.1:8080 -> 10.10.3.10:80), so it
  # needs an end-to-end TCP probe with a short-lived server on the inside.
  start_http_server forward-server 80 "diagnose probe" >/dev/null 2>&1 || true
  run_on forward-client curl -fsS --max-time 4 http://198.51.102.1:8080/ >/dev/null 2>&1 || { echo "         forward-client cannot reach the inside server via 198.51.102.1:8080"; status=1; }
  return "${status}"
}

CHECKS=(
  "Containers running|A node is down — deploy or restart the lab.|check_containers"
  "Gateway sysctls|A gateway will not route or drops return traffic; check net.ipv4.ip_forward and conf.all.rp_filter.|check_sysctls"
  "Interface MTU|A link MTU was lowered; large packets/TCP (MSS) may black-hole. Check 'ip link' on both ends.|check_mtu"
  "NAT tables|A gateway lost its 'ip nat4' table — re-run './lab.sh nat4 configure'.|check_nat"
  "Data path|Inside hosts cannot reach their outside server (static/dynamic/pat); inspect nft rules and conntrack with './lab.sh nat4 state'.|check_datapath"
)

run_diagnosis
