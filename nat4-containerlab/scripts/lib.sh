#!/usr/bin/env bash

LAB_NAME="nat4"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPOLOGY_FILE="${PROJECT_DIR}/clab.yml"
IMAGE_NAME="nat4-lab:latest"

CONTAINERS=(
  static-host static-gw static-server
  dynamic-host1 dynamic-host2 dynamic-gw dynamic-server
  forward-client forward-gw forward-server
  pat-host1 pat-host2 pat-gw pat-server
)

BRIDGES=(br-n4-si br-n4-so br-n4-di br-n4-do br-n4-fi br-n4-fo br-n4-pi br-n4-po)

container_name() {
  printf 'clab-%s-%s' "${LAB_NAME}" "$1"
}

run_on() {
  local node="$1"
  shift
  docker exec "$(container_name "${node}")" "$@"
}

run_on_stdin() {
  local node="$1"
  shift
  docker exec -i "$(container_name "${node}")" "$@"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: Required command not found: %s\n' "$1" >&2
    return 1
  fi
}

require_root() {
  if (( EUID != 0 )); then
    echo "ERROR: This operation requires root privileges. Run it with sudo." >&2
    return 1
  fi
}

require_container() {
  local node="$1"
  local name
  name="$(container_name "${node}")"
  if ! docker inspect "${name}" >/dev/null 2>&1; then
    echo "ERROR: Container ${name} does not exist. Deploy the lab first." >&2
    return 1
  fi
  if [[ "$(docker inspect -f '{{.State.Running}}' "${name}")" != "true" ]]; then
    echo "ERROR: Container ${name} is not running." >&2
    return 1
  fi
}

require_nodes() {
  local node
  for node in "$@"; do
    require_container "${node}"
  done
}

set_address() {
  local node="$1" interface="$2" address="$3"
  run_on "${node}" ip address replace "${address}" dev "${interface}"
  run_on "${node}" ip link set "${interface}" up
}

set_default_route() {
  local node="$1" gateway="$2"
  run_on "${node}" ip route replace default via "${gateway}" dev eth1
}

enable_gateway() {
  local node="$1"
  run_on "${node}" sysctl -q -w net.ipv4.ip_forward=1
  run_on "${node}" sysctl -q -w net.ipv4.conf.all.rp_filter=0
  run_on "${node}" sysctl -q -w net.ipv4.conf.default.rp_filter=0
}

reset_nat_table() {
  local gateway="$1"
  run_on "${gateway}" sh -c 'nft list table ip nat4 >/dev/null 2>&1 && nft delete table ip nat4 || true'
  run_on "${gateway}" conntrack -F >/dev/null 2>&1 || true
}

start_http_server() {
  local node="$1" port="$2" text="$3"
  require_container "${node}"
  run_on "${node}" sh -c "pkill -f '[h]ttpd.*-p ${port}' 2>/dev/null || true; mkdir -p /www; printf '%s\\n' '${text}' > /www/index.html"
  docker exec -d "$(container_name "${node}")" httpd -f -p "${port}" -h /www >/dev/null
  sleep 1
}

capture_pair() {
  local gateway="$1" inside_filter="$2" outside_filter="$3" duration="${4:-20}"
  local -a inside_filter_args outside_filter_args
  read -r -a inside_filter_args <<<"${inside_filter}"
  read -r -a outside_filter_args <<<"${outside_filter}"
  require_container "${gateway}"

  echo "Capturing for ${duration} seconds. Generate traffic in another terminal."
  echo "===== INSIDE BEFORE NAT (${gateway} eth1) ====="
  run_on "${gateway}" timeout "${duration}" tcpdump -l -nn -i eth1 "${inside_filter_args[@]}" 2>&1 | sed 's/^/[INSIDE]  /' &
  local inside_pid=$!
  echo "===== OUTSIDE AFTER NAT (${gateway} eth2) ====="
  run_on "${gateway}" timeout "${duration}" tcpdump -l -nn -i eth2 "${outside_filter_args[@]}" 2>&1 | sed 's/^/[OUTSIDE] /' &
  local outside_pid=$!

  wait "${inside_pid}" || true
  wait "${outside_pid}" || true
}

capture_for_test() {
  local gateway="$1" filter="$2" prefix="$3" duration="${4:-8}"
  local -a filter_args
  read -r -a filter_args <<<"${filter}"
  local inside_file="/tmp/${prefix}-inside.$$.log"
  local outside_file="/tmp/${prefix}-outside.$$.log"
  run_on "${gateway}" timeout "${duration}" tcpdump -l -nn -i eth1 "${filter_args[@]}" >"${inside_file}" 2>&1 &
  CAPTURE_INSIDE_PID=$!
  run_on "${gateway}" timeout "${duration}" tcpdump -l -nn -i eth2 "${filter_args[@]}" >"${outside_file}" 2>&1 &
  CAPTURE_OUTSIDE_PID=$!
  CAPTURE_INSIDE_FILE="${inside_file}"
  CAPTURE_OUTSIDE_FILE="${outside_file}"
  sleep 1
}

finish_test_capture() {
  wait "${CAPTURE_INSIDE_PID}" || true
  wait "${CAPTURE_OUTSIDE_PID}" || true
  CAPTURE_INSIDE_OUTPUT="$(cat "${CAPTURE_INSIDE_FILE}")"
  CAPTURE_OUTSIDE_OUTPUT="$(cat "${CAPTURE_OUTSIDE_FILE}")"
  echo "===== INSIDE BEFORE NAT ====="
  sed 's/^/[INSIDE]  /' <<<"${CAPTURE_INSIDE_OUTPUT}"
  echo "===== OUTSIDE AFTER NAT ====="
  sed 's/^/[OUTSIDE] /' <<<"${CAPTURE_OUTSIDE_OUTPUT}"
  rm -f "${CAPTURE_INSIDE_FILE}" "${CAPTURE_OUTSIDE_FILE}"
}

show_gateway_state() {
  local gateway="$1"
  echo "===== ${gateway}: nftables ====="
  run_on "${gateway}" nft list table ip nat4 2>/dev/null || echo "No ip nat4 table configured."
  echo "===== ${gateway}: conntrack ====="
  run_on "${gateway}" conntrack -L -o extended 2>/dev/null || true
}
