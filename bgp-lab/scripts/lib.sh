#!/usr/bin/env bash
# shellcheck disable=SC2034  # lab variables below are consumed by sourcing scripts

# Lab-specific configuration and helpers. Generic helpers (privilege handling,
# docker/containerlab wrappers, run_on, ...) live in ../../scripts/common.sh.
LAB_NAME="bgp-lab"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPOLOGY_FILE="${PROJECT_DIR}/bgp-lab.clab.yml"
ROUTERS=(r1 r2 r3 r4 r5 r6 r7)

# shellcheck source=../../scripts/common.sh
source "${PROJECT_DIR}/../scripts/common.sh"

vtysh_on() {
  local router="$1"
  shift
  local args=()
  local command
  for command in "$@"; do
    args+=( -c "${command}" )
  done
  run_on "${router}" vtysh "${args[@]}"
}
