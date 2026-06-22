#!/usr/bin/env bash
# shellcheck disable=SC2154  # LAB_NAME and FAULTS are provided by the caller
#
# Shared driver for a lab's `break` action. The caller (a lab's break.sh) sets
# LAB_NAME (via lib.sh) and FAULTS (via the lab's faults.sh), then calls
# run_break. FAULTS entries are "key|hint|fault_function"; the fault_* functions
# apply the fault silently — all user-facing text is printed here so a "mystery"
# fault is never revealed by accident.

LAB_SHORT="${LAB_NAME%-lab}"
FAULT_STATE_FILE="/tmp/clab-${LAB_NAME}.fault"

_fault_hint() {
  local key="$1" entry rest
  for entry in "${FAULTS[@]}"; do
    if [[ "${entry%%|*}" == "${key}" ]]; then
      rest="${entry#*|}"
      printf '%s' "${rest%%|*}"
      return 0
    fi
  done
}

_fault_fn() {
  local key="$1" entry
  for entry in "${FAULTS[@]}"; do
    [[ "${entry%%|*}" == "${key}" ]] && { printf '%s' "${entry##*|}"; return 0; }
  done
  return 1
}

# Print the fault sub-menu to stderr and the chosen key to stdout. Returns
# non-zero when the user cancels.
select_fault() {
  local i entry key hint width=6 choice
  for entry in "${FAULTS[@]}"; do key="${entry%%|*}"; (( ${#key} > width )) && width=${#key}; done
  {
    echo
    echo "  ${LAB_NAME} — inject a fault"
    echo "  ──────────────────────────────────────────────────"
    i=1
    for entry in "${FAULTS[@]}"; do
      key="${entry%%|*}"; hint="$(_fault_hint "${key}")"
      printf '  %2d) %-*s %s\n' "${i}" "${width}" "${key}" "${hint}"
      ((i++))
    done
    printf '  %2d) %-*s %s\n' "${i}" "${width}" "random" "inject a random fault without revealing it (mystery)"
    echo "   q) cancel"
    echo "  ──────────────────────────────────────────────────"
  } >&2
  read -rp "  Select a fault: " choice || return 1
  case "${choice}" in
    q|Q|quit|exit|"") return 1 ;;
    *[!0-9]*) echo "  Invalid choice: ${choice}" >&2; return 1 ;;
  esac
  if (( choice >= 1 && choice <= ${#FAULTS[@]} )); then
    printf '%s' "${FAULTS[choice-1]%%|*}"
  elif (( choice == ${#FAULTS[@]} + 1 )); then
    printf 'random'
  else
    echo "  Invalid choice: ${choice}" >&2
    return 1
  fi
}

run_break() {
  local key fn
  key="$(select_fault)" || { echo "Cancelled."; return 0; }

  if [[ "${key}" == "random" ]]; then
    key="${FAULTS[RANDOM % ${#FAULTS[@]}]%%|*}"
    fn="$(_fault_fn "${key}")"
    "${fn}"
    echo "mystery:${key}" >"${FAULT_STATE_FILE}"
    echo
    echo "A random fault has been injected — it is NOT revealed."
  else
    fn="$(_fault_fn "${key}")" || { echo "Unknown fault: ${key}" >&2; return 2; }
    "${fn}"
    echo "${key}" >"${FAULT_STATE_FILE}"
    echo
    echo "Injected fault '${key}': $(_fault_hint "${key}")"
  fi

  echo "Diagnose with:  ./lab.sh ${LAB_SHORT} verify     (also: state, inspect)"
  echo "Restore with:   ./lab.sh ${LAB_SHORT} heal"
}

# Called by heal.sh after it restores the baseline: reveals a mystery fault and
# clears the recorded state.
reveal_fault() {
  [[ -f "${FAULT_STATE_FILE}" ]] || return 0
  local rec key
  rec="$(cat "${FAULT_STATE_FILE}")"
  rm -f "${FAULT_STATE_FILE}"
  case "${rec}" in
    mystery:*)
      key="${rec#mystery:}"
      echo "The mystery fault was '${key}': $(_fault_hint "${key}")"
      ;;
  esac
}
