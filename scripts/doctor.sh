#!/usr/bin/env bash
set -uo pipefail

# Preflight environment check shared by all labs. Run via `./lab.sh doctor`.
# Verifies the host has what the labs need before a deploy is attempted.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "${ROOT_DIR}/scripts/common.sh"

# "directory|topology|image" per lab; empty image means the lab uses an
# upstream image and builds nothing locally.
LAB_CHECKS=(
  "bgp-lab|bgp-lab.clab.yml|"
  "ipsec-lab|ipsec-lab.clab.yml|ipsec-lab:latest"
  "nat4-lab|nat4-lab.clab.yml|nat4-lab:latest"
)

errors=0
warns=0
pass() { printf '  [ ok ] %s\n' "$1"; }
warn() { printf '  [warn] %s\n' "$1"; warns=$((warns + 1)); }
fail() { printf '  [FAIL] %s\n' "$1"; errors=$((errors + 1)); }

echo "ContainerLab environment check"
echo "──────────────────────────────"

echo "Core tools:"
if require_command docker 2>/dev/null; then
  pass "docker is installed"
  if docker_cmd info >/dev/null 2>&1; then
    if [[ "${DOCKER[0]}" == "sudo" ]]; then
      pass "docker daemon is reachable (via sudo; user is not in the docker group)"
    else
      pass "docker daemon is reachable"
    fi
  else
    fail "docker daemon is not reachable (is it running? do you have access?)"
  fi
else
  fail "docker is not installed"
fi

if require_command containerlab 2>/dev/null; then
  pass "containerlab is installed"
else
  fail "containerlab is not installed"
fi

if (( EUID == 0 )); then
  pass "running as root; no sudo needed"
elif require_command sudo 2>/dev/null; then
  pass "sudo is available for the steps that need root"
else
  warn "sudo not found; needed unless you run as root or are in the docker group"
fi

echo
echo "Labs:"
for entry in "${LAB_CHECKS[@]}"; do
  IFS='|' read -r dir topo image <<<"${entry}"
  echo "  ${dir}:"
  if [[ -f "${ROOT_DIR}/${dir}/${topo}" ]]; then
    pass "  topology ${topo} present"
  else
    fail "  topology ${topo} missing"
  fi
  if [[ -n "${image}" ]]; then
    if docker_cmd image inspect "${image}" >/dev/null 2>&1; then
      pass "  image ${image} built"
    else
      warn "  image ${image} not built yet (created on first deploy)"
    fi
  fi
done

echo
echo "──────────────────────────────"
if (( errors > 0 )); then
  echo "${errors} problem(s) and ${warns} warning(s). Fix the failures before deploying." >&2
  exit 1
fi
echo "Environment looks good (${warns} warning(s))."
