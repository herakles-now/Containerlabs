#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

configure_linux() {
  local router="$1"
  local dummy_address="$2"
  shift 2

  if (( $# % 2 != 0 )); then
    echo "ERROR: configure_linux for ${router} requires interface/address pairs." >&2
    return 2
  fi

  echo "Configuring Linux networking on ${router}..."
  run_on "${router}" sh -c 'ip link show dummy0 >/dev/null 2>&1 || ip link add dummy0 type dummy'
  run_on "${router}" ip address replace "${dummy_address}" dev dummy0
  run_on "${router}" ip link set dummy0 up
  run_on "${router}" sysctl -q -w net.ipv4.ip_forward=1

  while (( $# > 0 )); do
    local interface="$1"
    local address="$2"
    shift 2
    run_on "${router}" ip address replace "${address}" dev "${interface}"
    run_on "${router}" ip link set "${interface}" up
  done
}

wait_for_frr() {
  local router="$1"
  local attempt
  for attempt in {1..30}; do
    if vtysh_on "${router}" "show version" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: FRR did not become ready on ${router}." >&2
  run_on "${router}" ps aux >&2 || true
  return 1
}

configure_bgp() {
  local router="$1"
  local asn="$2"
  local router_id="$3"
  local network="$4"
  shift 4

  if (( $# % 2 != 0 )); then
    echo "ERROR: configure_bgp for ${router} requires peer/remote-AS pairs." >&2
    return 2
  fi
  local commands=(
    "configure terminal"
    "router bgp ${asn}"
    "bgp router-id ${router_id}"
    "no bgp ebgp-requires-policy"
    "bgp bestpath compare-routerid"
  )

  while (( $# > 0 )); do
    local peer="$1"
    local remote_as="$2"
    shift 2
    commands+=("neighbor ${peer} remote-as ${remote_as}")
  done

  commands+=(
    "address-family ipv4 unicast"
    "network ${network}"
    "exit-address-family"
    "end"
    "write memory"
  )

  echo "Configuring BGP on ${router} (AS${asn})..."
  vtysh_on "${router}" "${commands[@]}" >/dev/null
}

for router in "${ROUTERS[@]}"; do
  if ! docker inspect "$(container_name "${router}")" >/dev/null 2>&1; then
    echo "ERROR: Container $(container_name "${router}") does not exist. Deploy the lab first." >&2
    exit 1
  fi
done

configure_linux r1 10.1.0.1/16 eth1 192.168.12.1/30 eth2 192.168.13.1/30
configure_linux r2 10.2.0.1/16 eth1 192.168.12.2/30 eth2 192.168.25.1/30
configure_linux r3 10.4.0.1/16 eth1 192.168.13.2/30 eth2 192.168.35.1/30 eth3 192.168.34.1/30
configure_linux r4 10.5.0.1/16 eth1 192.168.34.2/30 eth2 192.168.46.1/30
configure_linux r5 10.3.0.1/16 eth1 192.168.25.2/30 eth2 192.168.35.2/30
configure_linux r6 10.6.0.1/16 eth1 192.168.46.2/30 eth2 192.168.67.1/30
configure_linux r7 10.7.0.1/16 eth1 192.168.67.2/30

for router in "${ROUTERS[@]}"; do
  wait_for_frr "${router}"
done

configure_bgp r1 100 1.1.1.1 10.1.0.0/16 192.168.12.2 200 192.168.13.2 400
configure_bgp r2 200 2.2.2.2 10.2.0.0/16 192.168.12.1 100 192.168.25.2 300
configure_bgp r3 400 3.3.3.3 10.4.0.0/16 192.168.13.1 100 192.168.35.2 300 192.168.34.2 500
configure_bgp r4 500 4.4.4.4 10.5.0.0/16 192.168.34.1 400 192.168.46.2 600
configure_bgp r5 300 5.5.5.5 10.3.0.0/16 192.168.25.1 200 192.168.35.1 400
configure_bgp r6 600 6.6.6.6 10.6.0.0/16 192.168.46.1 500 192.168.67.2 700
configure_bgp r7 700 7.7.7.7 10.7.0.0/16 192.168.67.1 600

echo "Configuration completed successfully."
