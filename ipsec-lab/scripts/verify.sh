#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

failures=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }

debug_node() {
  local node="$1"
  echo "===== Debug output: ${node} =====" >&2
  run_on "${node}" ip -br address >&2 || true
  run_on "${node}" ip route >&2 || true
  if [[ "${node}" == "r1" || "${node}" == "r2" ]]; then
    run_on "${node}" swanctl --list-sas >&2 || true
    run_on "${node}" swanctl --list-conns >&2 || true
    run_on "${node}" ip xfrm state >&2 || true
    run_on "${node}" ip xfrm policy >&2 || true
  fi
}

require_command docker

for node in "${NODES[@]}"; do
  if require_container "${node}"; then
    pass "Container $(container_name "${node}") is running"
  else
    fail "Container $(container_name "${node}") is unavailable"
  fi
done

if (( failures > 0 )); then
  exit 1
fi

for router in r1 r2; do
  connection_name="r1-r2"
  [[ "${router}" == "r2" ]] && connection_name="r2-r1"
  connections="$(run_on "${router}" swanctl --list-conns 2>&1 || true)"
  if grep -q "${connection_name}" <<<"${connections}" && grep -q 'lan-to-lan' <<<"${connections}"; then
    pass "Connection ${connection_name} is loaded on ${router}"
  else
    fail "Connection ${connection_name} is not loaded on ${router}"
  fi
done

echo "Triggering the site-to-site tunnel with traffic from PC1 to PC2..."
ping_ok=false
for _ in {1..20}; do
  if run_on pc1 ping -c 1 -W 1 10.2.0.10 >/dev/null 2>&1; then
    ping_ok=true
    break
  fi
  sleep 1
done

if [[ "${ping_ok}" == "true" ]]; then
  pass "PC1 can reach PC2 through the IPsec tunnel"
else
  fail "PC1 cannot reach PC2 through the IPsec tunnel"
fi

if run_on pc2 ping -c 2 -W 2 10.1.0.10 >/dev/null 2>&1; then
  pass "PC2 can reach PC1 through the IPsec tunnel"
else
  fail "PC2 cannot reach PC1 through the IPsec tunnel"
fi

for router in r1 r2; do
  sas="$(run_on "${router}" swanctl --list-sas 2>&1 || true)"
  if grep -q 'ESTABLISHED' <<<"${sas}" && grep -q 'lan-to-lan' <<<"${sas}"; then
    pass "IKE and lan-to-lan CHILD_SA are established on ${router}"
  else
    fail "Expected IKE/CHILD_SA is missing on ${router}"
  fi

  if [[ -n "$(run_on "${router}" ip xfrm state 2>/dev/null)" ]]; then
    pass "Kernel XFRM state exists on ${router}"
  else
    fail "Kernel XFRM state is missing on ${router}"
  fi
done

if (( failures > 0 )); then
  echo "${failures} verification check(s) failed. Collecting diagnostics..." >&2
  for node in "${NODES[@]}"; do
    if docker_cmd inspect "$(container_name "${node}")" >/dev/null 2>&1; then
      debug_node "${node}"
    fi
  done
  exit 1
fi

echo "All IPsec verification checks passed."
