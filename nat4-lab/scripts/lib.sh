#!/usr/bin/env bash

LAB_NAME="nat4-lab"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPOLOGY_FILE="${PROJECT_DIR}/nat4-lab.clab.yml"
IMAGE_NAME="nat4-lab:latest"

CONTAINERS=(
  static-host static-gw static-server
  dynamic-host1 dynamic-host2 dynamic-gw dynamic-server
  forward-client forward-gw forward-server
  pat-host1 pat-host2 pat-gw pat-server
)

BRIDGES=(br-n4-si br-n4-so br-n4-di br-n4-do br-n4-fi br-n4-fo br-n4-pi br-n4-po)

# Command prefixes for operations that may need elevated privileges. The
# scripts run as the invoking user; detect_privilege() fills these in on
# first use and escalates to sudo only when it is actually required.
DOCKER=(docker)
SUDO=()

container_name() {
  printf 'clab-%s-%s' "${LAB_NAME}" "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: Required command not found: %s\n' "$1" >&2
    return 1
  fi
}

# Ask a yes/no question. A bare Enter means "yes". Returns non-zero (treated
# as "no") when there is no interactive terminal, so non-interactive runs
# fall back to the manual path instead of blocking.
prompt_yes_no() {
  local question="$1" reply
  [[ -t 0 ]] || return 1
  read -rp "${question} [Y/n] " reply || return 1
  case "${reply}" in
    n|N|no|No|NO) return 1 ;;
    *) return 0 ;;
  esac
}

# Decide, once, whether docker, containerlab and host network commands need
# sudo. containerlab and host bridge/namespace operations always need root;
# docker only needs sudo when the user is not in the 'docker' group. Running
# as root needs no escalation at all.
detect_privilege() {
  [[ -n "${_PRIVILEGE_DETECTED:-}" ]] && return 0

  if (( EUID == 0 )); then
    DOCKER=(docker)
    SUDO=()
    _PRIVILEGE_DETECTED=1
    return 0
  fi

  require_command sudo || return 1

  if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
  else
    DOCKER=(sudo docker)
  fi
  SUDO=(sudo)

  _PRIVILEGE_DETECTED=1
  return 0
}

# Prime the sudo credential cache so the password is requested once, up
# front, instead of in the middle of a long-running deploy/destroy.
ensure_sudo() {
  detect_privilege || return 1
  if (( ${#SUDO[@]} > 0 )); then
    echo "Elevated privileges are required; you may be prompted for your sudo password." >&2
    sudo -v
  fi
}

# Run docker, escalating to sudo only when the daemon is not reachable as
# the current user.
docker_cmd() {
  detect_privilege || return 1
  "${DOCKER[@]}" "$@"
}

# Run containerlab, escalating to sudo when not already root.
clab() {
  detect_privilege || return 1
  "${SUDO[@]}" containerlab "$@"
}

# Run a host command that needs root (e.g. host bridge management),
# escalating to sudo when not already root.
as_root() {
  detect_privilege || return 1
  "${SUDO[@]}" "$@"
}

run_on() {
  local node="$1"
  shift
  docker_cmd exec "$(container_name "${node}")" "$@"
}

run_on_stdin() {
  local node="$1"
  shift
  docker_cmd exec -i "$(container_name "${node}")" "$@"
}

require_container() {
  local node="$1"
  local name
  name="$(container_name "${node}")"
  if ! docker_cmd inspect "${name}" >/dev/null 2>&1; then
    echo "ERROR: Container ${name} does not exist. Deploy the lab first." >&2
    return 1
  fi
  if [[ "$(docker_cmd inspect -f '{{.State.Running}}' "${name}")" != "true" ]]; then
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

# Per-case test traffic for the live captures. Each generator (re)applies the
# scenario's nftables rules (which also flushes conntrack) and then drives the
# same flow the matching test uses, so an opt-in capture is self-contained.
NAT_SCRIPTS="${PROJECT_DIR}/scripts"

generate_static_traffic() {
  "${NAT_SCRIPTS}/configure-static-nat.sh" >/dev/null
  start_http_server static-server 80 "static NAT outside server"
  echo "[traffic] 10.10.1.10:41000 -> 198.51.100.100:80"
  run_on static-host sh -c 'printf "GET / HTTP/1.0\r\nHost: static\r\n\r\n" | nc -p 41000 -w 3 198.51.100.100 80' >/dev/null || true
}

generate_dynamic_traffic() {
  "${NAT_SCRIPTS}/configure-dynamic-nat.sh" >/dev/null
  start_http_server dynamic-server 80 "dynamic NAT outside server"
  echo "[traffic] two flows from 10.10.2.10/.11, source port 42000"
  run_on dynamic-host1 sh -c 'printf "GET / HTTP/1.0\r\nHost: dynamic1\r\n\r\n" | nc -p 42000 -w 3 198.51.101.100 80' >/dev/null &
  run_on dynamic-host2 sh -c 'printf "GET / HTTP/1.0\r\nHost: dynamic2\r\n\r\n" | nc -p 42000 -w 3 198.51.101.100 80' >/dev/null &
  wait
}

generate_forward_traffic() {
  "${NAT_SCRIPTS}/configure-port-forward.sh" >/dev/null
  start_http_server forward-server 80 "inside server reached through port forwarding"
  echo "[traffic] outside client -> 198.51.102.1:8080"
  run_on forward-client curl -fsS --max-time 4 http://198.51.102.1:8080/ >/dev/null || true
}

generate_pat_traffic() {
  "${NAT_SCRIPTS}/configure-pat.sh" >/dev/null
  start_http_server pat-server 80 "PAT outside server"
  echo "[traffic] two flows from 10.10.4.10/.11, source port 43000"
  run_on pat-host1 sh -c 'printf "GET / HTTP/1.0\r\nHost: pat1\r\n\r\n" | nc -p 43000 -w 4 198.51.103.100 80' >/dev/null &
  run_on pat-host2 sh -c 'printf "GET / HTTP/1.0\r\nHost: pat2\r\n\r\n" | nc -p 43000 -w 4 198.51.103.100 80' >/dev/null &
  wait
}

# Live dual-interface capture. With an optional generator function and manual
# command hint, it offers to fire the matching test traffic itself once the
# capture is up; otherwise it tells you how to drive it from another terminal.
capture_pair() {
  local gateway="$1" inside_filter="$2" outside_filter="$3" duration="${4:-20}"
  local generator="${5:-}" manual_cmd="${6:-}"
  local -a inside_filter_args outside_filter_args
  read -r -a inside_filter_args <<<"${inside_filter}"
  read -r -a outside_filter_args <<<"${outside_filter}"
  require_container "${gateway}"

  local auto=false
  if [[ -n "${generator}" ]]; then
    if prompt_yes_no "Auto-generate the matching test traffic once the capture is up?"; then
      auto=true
      # The traffic fires within seconds, so the auto window is short unless
      # DURATION is set explicitly.
      duration="${DURATION:-8}"
    else
      echo "OK — generate traffic yourself during the ${duration}s window, e.g. in another terminal:"
      [[ -n "${manual_cmd}" ]] && echo "    ${manual_cmd}"
    fi
  fi

  echo "Capturing for ${duration} seconds on ${gateway} (eth1 inside, eth2 outside)."
  echo "===== INSIDE BEFORE NAT (${gateway} eth1) ====="
  run_on "${gateway}" timeout "${duration}" tcpdump -l -nn -i eth1 "${inside_filter_args[@]}" 2>&1 | sed 's/^/[INSIDE]  /' &
  local inside_pid=$!
  echo "===== OUTSIDE AFTER NAT (${gateway} eth2) ====="
  run_on "${gateway}" timeout "${duration}" tcpdump -l -nn -i eth2 "${outside_filter_args[@]}" 2>&1 | sed 's/^/[OUTSIDE] /' &
  local outside_pid=$!

  local gen_pid=""
  if [[ "${auto}" == true ]]; then
    # Delay so the traffic lands after tcpdump is actually listening.
    ( sleep 2; "${generator}" ) &
    gen_pid=$!
  fi

  wait "${inside_pid}" || true
  wait "${outside_pid}" || true
  [[ -n "${gen_pid}" ]] && wait "${gen_pid}" 2>/dev/null
  return 0
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
