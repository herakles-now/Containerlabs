#!/usr/bin/env bash

LAB_NAME="ipsec-lab"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPOLOGY_FILE="${PROJECT_DIR}/ipsec-lab.clab.yml"
IMAGE_NAME="ipsec-alpine:latest"
NODES=(pc1 r1 transit r2 pc2)

container_name() {
  printf 'clab-%s-%s' "${LAB_NAME}" "$1"
}

run_on() {
  local node="$1"
  shift
  docker exec "$(container_name "${node}")" "$@"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: Required command not found: %s\n' "$1" >&2
    return 1
  fi
}

require_root() {
  if (( EUID != 0 )); then
    echo "ERROR: Containerlab requires root privileges. Run this command with sudo." >&2
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
