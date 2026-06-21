#!/usr/bin/env bash

# Shared helpers. This file is sourced by the executable scripts.
LAB_NAME="bgp-lab"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPOLOGY_FILE="${PROJECT_DIR}/bgp-lab.clab.yml"
ROUTERS=(r1 r2 r3 r4 r5 r6 r7)

container_name() {
  printf 'clab-%s-%s' "${LAB_NAME}" "$1"
}

run_on() {
  local router="$1"
  shift
  docker exec "$(container_name "${router}")" "$@"
}

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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: Required command not found: %s\n' "$1" >&2
    return 1
  fi
}

require_root() {
  if (( EUID != 0 )); then
    echo "ERROR: Containerlab requires root privileges on this system. Run this command with sudo." >&2
    return 1
  fi
}
