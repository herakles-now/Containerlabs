#!/usr/bin/env bash
# shellcheck disable=SC2034  # lab variables below are consumed by sourcing scripts

# Shared helpers. This file is sourced by the executable scripts.
LAB_NAME="ipsec-lab"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPOLOGY_FILE="${PROJECT_DIR}/ipsec-lab.clab.yml"
IMAGE_NAME="ipsec-lab:latest"
NODES=(pc1 r1 transit r2 pc2)

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

# Decide, once, whether docker and containerlab need sudo. containerlab
# always needs root because it manipulates host network namespaces and
# veth pairs; docker only needs sudo when the user is not a member of the
# 'docker' group. Running as root needs no escalation at all.
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

run_on() {
  local node="$1"
  shift
  docker_cmd exec "$(container_name "${node}")" "$@"
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
