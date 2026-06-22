#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

failures=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }

debug_router() {
  local router="$1"
  echo
  echo "===== Debug output: ${router} =====" >&2
  vtysh_on "${router}" "show bgp summary" "show bgp ipv4 unicast" "show ip route bgp" >&2 || true
  run_on "${router}" ip route >&2 || true
  run_on "${router}" ip addr >&2 || true
}

check_established_peer() {
  local router="$1"
  local peer="$2"
  local summary="$3"
  # Locate State/PfxRcd from the header because newer FRR releases append
  # additional columns such as PfxSnt and Desc after it.
  if awk -v peer="${peer}" '
    $1 == "Neighbor" {
      for (i = 1; i <= NF; i++) {
        if ($i == "State/PfxRcd") column = i
      }
    }
    $1 == peer && column && $column ~ /^[0-9]+$/ { found=1 }
    END { exit !found }
  ' <<<"${summary}"; then
    pass "${router} peer ${peer} is Established"
  else
    fail "${router} peer ${peer} is not Established"
  fi
}

require_command docker || exit 1

for router in "${ROUTERS[@]}"; do
  name="$(container_name "${router}")"
  if docker_cmd inspect "${name}" >/dev/null 2>&1; then
    pass "Container ${name} exists"
  else
    fail "Container ${name} is missing"
    continue
  fi

  if [[ "$(docker_cmd inspect -f '{{.State.Running}}' "${name}" 2>/dev/null)" == "true" ]]; then
    pass "Container ${name} is running"
  else
    fail "Container ${name} is not running"
    continue
  fi

  if vtysh_on "${router}" "show version" >/dev/null 2>&1; then
    pass "FRR/vtysh is available on ${router}"
  else
    fail "FRR/vtysh is unavailable on ${router}"
  fi

  if [[ "$(run_on "${router}" cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" == "1" ]]; then
    pass "${router} has IPv4 forwarding enabled"
  else
    fail "${router} does not have IPv4 forwarding enabled"
  fi

  if [[ -n "$(run_on "${router}" ip route show dev dummy0 2>/dev/null)" ]]; then
    pass "${router} has its dummy0 connected route"
  else
    fail "${router} is missing its dummy0 connected route"
  fi
done

declare -A PEERS=(
  [r1]="192.168.12.2 192.168.13.2"
  [r2]="192.168.12.1 192.168.25.2"
  [r3]="192.168.13.1 192.168.35.2 192.168.34.2"
  [r4]="192.168.34.1 192.168.46.2"
  [r5]="192.168.25.1 192.168.35.1"
  [r6]="192.168.46.1 192.168.67.2"
  [r7]="192.168.67.1"
)

for router in "${ROUTERS[@]}"; do
  echo
  echo "===== ${router}: show bgp summary ====="
  if summary="$(vtysh_on "${router}" "show bgp summary" 2>&1)"; then
    echo "${summary}"
    for peer in ${PEERS[${router}]}; do
      check_established_peer "${router}" "${peer}" "${summary}"
    done
  else
    echo "${summary}" >&2
    fail "Could not read BGP summary on ${router}"
  fi
done

echo
echo "===== R1 route checks ====="
for prefix in 10.1.0.0/16 10.2.0.0/16 10.3.0.0/16 10.4.0.0/16 10.5.0.0/16 10.6.0.0/16 10.7.0.0/16; do
  if route_output="$(vtysh_on r1 "show bgp ipv4 unicast ${prefix}" 2>&1)" && grep -Fq "BGP routing table entry for ${prefix}" <<<"${route_output}"; then
    pass "R1 has ${prefix} in its BGP table"
  else
    fail "R1 does not have ${prefix} in its BGP table"
  fi
done

r5_paths="$(vtysh_on r1 "show bgp ipv4 unicast 10.3.0.0/16" 2>&1 || true)"
if grep -Eq '(^|[[:space:]])200 300([[:space:]]|$)' <<<"${r5_paths}"; then
  pass "R1 has the AS200 AS300 path to 10.3.0.0/16"
else
  fail "R1 is missing the AS200 AS300 path to 10.3.0.0/16"
fi
if grep -Eq '(^|[[:space:]])400 300([[:space:]]|$)' <<<"${r5_paths}"; then
  pass "R1 has the AS400 AS300 path to 10.3.0.0/16"
else
  fail "R1 is missing the AS400 AS300 path to 10.3.0.0/16"
fi

if run_on r1 ping -c 3 -W 2 -I 10.1.0.1 10.7.0.1 >/dev/null 2>&1; then
  pass "R1 can ping 10.7.0.1 from 10.1.0.1"
else
  fail "R1 cannot ping 10.7.0.1 from 10.1.0.1"
fi
if run_on r7 ping -c 3 -W 2 -I 10.7.0.1 10.1.0.1 >/dev/null 2>&1; then
  pass "R7 can ping 10.1.0.1 from 10.7.0.1"
else
  fail "R7 cannot ping 10.1.0.1 from 10.7.0.1"
fi

if (( failures > 0 )); then
  echo
  echo "${failures} verification check(s) failed. Collecting diagnostics..." >&2
  for router in "${ROUTERS[@]}"; do
    if docker_cmd inspect "$(container_name "${router}")" >/dev/null 2>&1; then
      debug_router "${router}"
    fi
  done
  exit 1
fi

echo
echo "All verification checks passed."
