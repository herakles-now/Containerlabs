#!/usr/bin/env bash
# shellcheck disable=SC2154  # SCRIPT_DIR/LAB_TITLE/ACTIONS are set by the caller
#
# Shared interactive-menu engine for a lab's lab.sh. Before sourcing this file
# the caller sets:
#   SCRIPT_DIR  - directory holding the lab's action scripts
#   LAB_TITLE   - title shown in the menu header
#   ACTIONS     - array of "action|script|description" entries
# and then calls: lab_dispatch "$@"

# Width of the action column, derived from the longest action name so every
# lab lines up without a hand-tuned printf width.
_action_width() {
  local entry action width=4
  for entry in "${ACTIONS[@]}"; do
    action="${entry%%|*}"
    (( ${#action} > width )) && width=${#action}
  done
  printf '%s' "${width}"
}

script_for() {
  local action="$1" entry rest
  for entry in "${ACTIONS[@]}"; do
    if [[ "${entry%%|*}" == "${action}" ]]; then
      rest="${entry#*|}"
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
  local entry action desc width
  width="$(_action_width)"
  echo "Usage: ${0##*/} [action]"
  echo
  echo "Actions:"
  for entry in "${ACTIONS[@]}"; do
    action="${entry%%|*}"
    desc="${entry##*|}"
    printf '  %-*s %s\n' "${width}" "${action}" "${desc}"
  done
  echo
  echo "Run without an action for an interactive menu."
}

# Machine-readable list of "action<TAB>description" lines (via `lab.sh --list`),
# handy for scripting or shell completion.
list_actions() {
  local entry
  for entry in "${ACTIONS[@]}"; do
    printf '%s\t%s\n' "${entry%%|*}" "${entry##*|}"
  done
}

print_menu() {
  local i=1 entry action desc width
  width="$(_action_width)"
  echo
  echo "  ${LAB_TITLE} — choose an action"
  echo "  ────────────────────────────────────────────────────"
  for entry in "${ACTIONS[@]}"; do
    action="${entry%%|*}"
    desc="${entry##*|}"
    printf '   %d) %-*s %s\n' "${i}" "${width}" "${action}" "${desc}"
    ((i++))
  done
  echo "   q) quit"
  echo "  ────────────────────────────────────────────────────"
}

menu_loop() {
  local choice action
  while true; do
    print_menu
    read -rp "  Select an option: " choice || { echo; break; }
    case "${choice}" in
      q|Q|quit|exit) echo; break ;;
      "") continue ;;
      *[!0-9]*) echo "  Invalid choice: ${choice}" >&2; continue ;;
      *)
        if (( choice >= 1 && choice <= ${#ACTIONS[@]} )); then
          action="${ACTIONS[choice-1]%%|*}"
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

lab_dispatch() {
  case "${1:-}" in
    "")             menu_loop ;;
    -h|--help|help) usage ;;
    --list)         list_actions ;;
    *)              run_action "$1" ;;
  esac
}
