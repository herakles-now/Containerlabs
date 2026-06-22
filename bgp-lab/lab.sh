#!/usr/bin/env bash
set -uo pipefail

# Entry point for the bgp-lab. Run without arguments for an interactive
# menu, or pass an action directly, e.g. `./lab.sh deploy`.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_DIR}/scripts"

# Ordered list of "action|script|description" entries. The menu and the
# command dispatcher are both generated from this single source.
ACTIONS=(
  "deploy|deploy.sh|Deploy the lab, configure it and verify"
  "configure|configure.sh|(Re)apply the Linux and BGP configuration"
  "verify|verify.sh|Run all verification checks"
  "routes|show-routes.sh|Show BGP summaries and routes"
  "prefer-r3|prefer-r3-to-r5.sh|Apply the Local-Preference policy on R1"
  "reset-policy|reset-policy.sh|Remove the Local-Preference policy"
  "destroy|destroy.sh|Tear the lab down"
)

script_for() {
  local action="$1" entry
  for entry in "${ACTIONS[@]}"; do
    if [[ "${entry%%|*}" == "${action}" ]]; then
      local rest="${entry#*|}"
      printf '%s\n' "${rest%%|*}"
      return 0
    fi
  done
  return 1
}

run_action() {
  local action="$1" script
  if ! script="$(script_for "${action}")"; then
    echo "Unknown action: ${action}" >&2
    usage >&2
    return 2
  fi
  "${SCRIPT_DIR}/${script}"
}

usage() {
  local entry
  echo "Usage: ${0##*/} [action]"
  echo
  echo "Actions:"
  for entry in "${ACTIONS[@]}"; do
    local action="${entry%%|*}"
    local desc="${entry##*|}"
    printf '  %-13s %s\n' "${action}" "${desc}"
  done
  echo
  echo "Run without an action for an interactive menu."
}

# Machine-readable list of "action<TAB>description" lines, consumed by the
# top-level launcher to build its aggregated menu.
list_actions() {
  local entry
  for entry in "${ACTIONS[@]}"; do
    printf '%s\t%s\n' "${entry%%|*}" "${entry##*|}"
  done
}

print_menu() {
  local i=1 entry
  echo
  echo "  bgp-lab — choose an action"
  echo "  ────────────────────────────────────────────────────"
  for entry in "${ACTIONS[@]}"; do
    local action="${entry%%|*}"
    local desc="${entry##*|}"
    printf '   %d) %-13s %s\n' "${i}" "${action}" "${desc}"
    ((i++))
  done
  echo "   q) quit"
  echo "  ────────────────────────────────────────────────────"
}

menu_loop() {
  local choice
  while true; do
    print_menu
    read -rp "  Select an option: " choice || { echo; break; }
    case "${choice}" in
      q|Q|quit|exit) echo; break ;;
      "") continue ;;
      *[!0-9]*) echo "  Invalid choice: ${choice}" >&2; continue ;;
      *)
        if (( choice >= 1 && choice <= ${#ACTIONS[@]} )); then
          local action="${ACTIONS[choice-1]%%|*}"
          echo
          run_action "${action}" || echo "  '${action}' exited with a non-zero status." >&2
          echo
          read -rp "  Press Enter to return to the menu... " _ || break
        else
          echo "  Invalid choice: ${choice}" >&2
        fi
        ;;
    esac
  done
}

case "${1:-}" in
  "")          menu_loop ;;
  -h|--help|help) usage ;;
  --list)      list_actions ;;
  *)           run_action "$1" ;;
esac
