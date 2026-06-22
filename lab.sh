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
  echo "  lint    Lint all shell scripts (bash -n + shellcheck)"
  echo
  echo "Examples:"
  echo "  ${0##*/}                 Interactive launcher"
  echo "  ${0##*/} bgp             Open the bgp-lab menu"
  echo "  ${0##*/} nat4 deploy     Run a single action in nat4-lab"
  echo "  ${0##*/} lint            Lint all shell scripts"
  echo
  echo "Run without arguments for the interactive launcher."
}

# Build a flat list of selectable menu entries. Each lab contributes an
# "open menu" entry followed by its own actions (queried via `lab.sh --list`).
# Entries are stored as "kind|key|action|description"; kind is menu|action.
ENTRIES=()
build_entries() {
  ENTRIES=()
  local entry key dir script action desc
  for entry in "${LABS[@]}"; do
    key="${entry%%|*}"
    dir="$(lab_dir "${key}")"
    script="${ROOT_DIR}/${dir}/lab.sh"
    ENTRIES+=("menu|${key}||open the ${dir} menu")
    [[ -x "${script}" ]] || continue
    while IFS=$'\t' read -r action desc; do
      [[ -n "${action}" ]] || continue
      ENTRIES+=("action|${key}|${action}|${desc}")
    done < <("${script}" --list 2>/dev/null)
  done
}

print_menu() {
  local i=1 entry kind key action desc last_key=""
  echo
  echo "  ContainerLab — choose a lab or action"
  echo "  ────────────────────────────────────────────────────────────"
  for entry in "${ENTRIES[@]}"; do
    IFS='|' read -r kind key action desc <<<"${entry}"
    if [[ "${key}" != "${last_key}" ]]; then
      echo "  $(lab_dir "${key}")"
      last_key="${key}"
    fi
    if [[ "${kind}" == "menu" ]]; then
      printf '  %2d)   %-16s %s\n' "${i}" "menu" "${desc}"
    else
      printf '  %2d)   %-16s %s\n' "${i}" "${action}" "${desc}"
    fi
    ((i++))
  done
  echo "   q) quit"
  echo "  ────────────────────────────────────────────────────────────"
}

run_entry() {
  local entry="$1" kind key action desc script
  IFS='|' read -r kind key action desc <<<"${entry}"
  script="$(lab_script "${key}")"
  if [[ "${kind}" == "menu" ]]; then
    "${script}"
  else
    "${script}" "${action}"
  fi
}

menu_loop() {
  local choice
  build_entries
  while true; do
    print_menu
    read -rp "  Select an option: " choice || { echo; break; }
    case "${choice}" in
      q|Q|quit|exit) echo; break ;;
      "") continue ;;
      *[!0-9]*) echo "  Invalid choice: ${choice}" >&2; continue ;;
      *)
        if (( choice >= 1 && choice <= ${#ENTRIES[@]} )); then
          echo
          run_entry "${ENTRIES[choice-1]}" || echo "  Action exited with a non-zero status." >&2
          echo
          read -rp "  Press Enter to return to the launcher... " _ || break
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
