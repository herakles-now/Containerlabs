#!/usr/bin/env bash
set -uo pipefail

# Top-level entry point for the ContainerLab labs. Run without arguments for
# an interactive launcher that lets you open a lab's own menu or run any of
# its actions directly. From the command line:
#
#   ./lab.sh                 # interactive launcher
#   ./lab.sh <lab>           # open a lab's interactive menu
#   ./lab.sh <lab> <action>  # run a single action in that lab
#
# e.g. ./lab.sh bgp deploy, ./lab.sh nat4 test-static, ./lab.sh ipsec destroy

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ordered "key|directory|description" entries for each lab.
LABS=(
  "bgp|bgp-lab|Seven-AS FRRouting eBGP lab"
  "ipsec|ipsec-lab|strongSwan IPsec site-to-site VPN"
  "nat4|nat4-lab|Four nftables NAT scenarios"
)

lab_dir() {
  local key="$1" entry
  for entry in "${LABS[@]}"; do
    if [[ "${entry%%|*}" == "${key}" ]]; then
      local rest="${entry#*|}"
      printf '%s\n' "${rest%%|*}"
      return 0
    fi
  done
  return 1
}

lab_script() {
  local key="$1" dir
  dir="$(lab_dir "${key}")" || return 1
  printf '%s/%s/lab.sh\n' "${ROOT_DIR}" "${dir}"
}

# True if a lab's lab.sh defines the given action.
lab_has_action() {
  local script="$1" action="$2"
  "${script}" --list | cut -f1 | grep -qx "${action}"
}

# Run one action across every lab in turn. A lab that doesn't define the
# action is skipped with a note; for "clean" we fall back to "destroy" so a
# clean-all still tears down labs that have no image to remove. Returns 1 if
# any lab exited non-zero.
run_all() {
  local action="$1" entry key script effective rc=0
  for entry in "${LABS[@]}"; do
    key="${entry%%|*}"
    script="$(lab_script "${key}")"
    effective="${action}"
    if ! lab_has_action "${script}" "${effective}"; then
      if [[ "${action}" == "clean" ]] && lab_has_action "${script}" "destroy"; then
        effective="destroy"
      else
        echo
        echo "  ── ${key}: no '${action}' action, skipping ──"
        continue
      fi
    fi
    echo
    echo "  ── ${key}: ${effective} ──"
    if ! "${script}" "${effective}"; then
      rc=1
      echo "  '${key} ${effective}' exited with a non-zero status." >&2
    fi
  done
  return "${rc}"
}

usage() {
  local entry
  echo "Usage: ${0##*/} [lab] [action]"
  echo
  echo "Labs:"
  for entry in "${LABS[@]}"; do
    local key="${entry%%|*}"
    local desc="${entry##*|}"
    printf '  %-6s %s\n' "${key}" "${desc}"
  done
  echo
  echo "Global actions:"
  echo "  up      Deploy every lab"
  echo "  down    Destroy every lab"
  echo "  clean   Clean every lab (destroy + remove images)"
  echo "  doctor  Check the host has docker, containerlab and sudo"
  echo "  lint    Lint all shell scripts (bash -n + shellcheck)"
  echo
  echo "Examples:"
  echo "  ${0##*/}                 Interactive launcher"
  echo "  ${0##*/} bgp             Open the bgp-lab menu"
  echo "  ${0##*/} nat4 deploy     Run a single action in nat4-lab"
  echo "  ${0##*/} up              Deploy all labs"
  echo "  ${0##*/} doctor          Check the environment"
  echo
  echo "Run without arguments for the interactive launcher."
}

# Launcher menu: pick a lab, then its own lab.sh menu opens. Quitting that
# inner menu (q) returns here so another lab can be chosen.
print_menu() {
  local i=1 entry key desc
  echo
  echo "  ContainerLab — choose a lab"
  echo "  ──────────────────────────────────────────────────"
  for entry in "${LABS[@]}"; do
    key="${entry%%|*}"
    desc="${entry##*|}"
    printf '  %2d) %-6s %s\n' "${i}" "${key}" "${desc}"
    ((i++))
  done
  echo "  ──────────────────────────────────────────────────"
  echo "   u) up      Deploy every lab"
  echo "   d) down    Destroy every lab"
  echo "   c) clean   Clean every lab (destroy + remove images)"
  echo "   q) quit"
  echo "  ──────────────────────────────────────────────────"
}

menu_loop() {
  local choice key script
  while true; do
    print_menu
    read -rp "  Select a lab: " choice || { echo; break; }
    case "${choice}" in
      q|Q|quit|exit) echo; break ;;
      u|U|up)    echo; run_all deploy; echo; read -rp "  Press Enter to return... " _ || break; continue ;;
      d|D|down)  echo; run_all destroy; echo; read -rp "  Press Enter to return... " _ || break; continue ;;
      c|C|clean) echo; run_all clean; echo; read -rp "  Press Enter to return... " _ || break; continue ;;
      "") continue ;;
      *[!0-9]*) echo "  Invalid choice: ${choice}" >&2; continue ;;
      *)
        if (( choice >= 1 && choice <= ${#LABS[@]} )); then
          key="${LABS[choice-1]%%|*}"
          script="$(lab_script "${key}")"
          echo
          "${script}"
        else
          echo "  Invalid choice: ${choice}" >&2
        fi
        ;;
    esac
  done
}

case "${1:-}" in
  "")             menu_loop ;;
  -h|--help|help) usage ;;
  lint)           shift; exec "${ROOT_DIR}/scripts/lint.sh" "$@" ;;
  doctor)         shift; exec "${ROOT_DIR}/scripts/doctor.sh" "$@" ;;
  up)             run_all deploy ;;
  down)           run_all destroy ;;
  clean)          run_all clean ;;
  *)
    if script="$(lab_script "$1")"; then
      shift
      "${script}" "$@"
    else
      echo "Unknown lab: $1" >&2
      usage >&2
      exit 2
    fi
    ;;
esac
