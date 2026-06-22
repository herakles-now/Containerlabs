#!/usr/bin/env bash
# shellcheck disable=SC2034  # DOCKER/SUDO are read by sourcing scripts
#
# Shared helpers for all ContainerLab labs. Each lab's scripts/lib.sh sets the
# lab-specific variables (LAB_NAME, TOPOLOGY_FILE, node lists, ...) and then
# sources this file. It is safe to source without LAB_NAME set (e.g. from
# scripts/doctor.sh): container_name() only reads LAB_NAME when it is called.

# Command prefixes for operations that may need elevated privileges. The
# scripts run as the invoking user; detect_privilege() fills these in on first
# use and escalates to sudo only when it is actually required.
DOCKER=(docker)
SUDO=()

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: Required command not found: %s\n' "$1" >&2
    return 1
  fi
}

container_name() {
  printf 'clab-%s-%s' "${LAB_NAME}" "$1"
}

# Ask a yes/no question. A bare Enter means "yes". Returns non-zero (treated
# as "no") when there is no interactive terminal, so non-interactive runs fall
# back to the manual path instead of blocking.
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

  # Docker is reachable directly when the user is in the 'docker' group;
  # otherwise fall back to sudo for docker as well.
  if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
  else
    DOCKER=(sudo docker)
  fi
  SUDO=(sudo)

  _PRIVILEGE_DETECTED=1
  return 0
}

# Prime the sudo credential cache so the password is requested once, up front,
# instead of in the middle of a long-running deploy/destroy.
ensure_sudo() {
  detect_privilege || return 1
  if (( ${#SUDO[@]} > 0 )); then
    echo "Elevated privileges are required; you may be prompted for your sudo password." >&2
    sudo -v
  fi
}

# Run docker, escalating to sudo only when the daemon is not reachable as the
# current user.
docker_cmd() {
  detect_privilege || return 1
  "${DOCKER[@]}" "$@"
}

# Run containerlab, escalating to sudo when not already root.
clab() {
  detect_privilege || return 1
  "${SUDO[@]}" containerlab "$@"
}

# Run a host command that needs root (e.g. host bridge management), escalating
# to sudo when not already root.
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
  local node status=0
  for node in "$@"; do
    require_container "${node}" || status=1
  done
  return "${status}"
}

# Print the containerlab graph and inventory for the current lab (reads
# TOPOLOGY_FILE). Each subcommand is guarded so an older containerlab that
# lacks one (e.g. `inspect interfaces`) does not abort the overview.
clab_overview() {
  if ! command -v containerlab >/dev/null 2>&1; then
    echo "containerlab is not installed."
    return 0
  fi
  echo "===== containerlab graph (mermaid) ====="
  clab graph --topo "${TOPOLOGY_FILE}" --mermaid || true
  echo
  echo "===== containerlab inspect ====="
  clab inspect --topo "${TOPOLOGY_FILE}" --wide || true
  echo
  echo "===== containerlab interfaces ====="
  clab inspect interfaces --topo "${TOPOLOGY_FILE}" || true
}
