#!/usr/bin/env bash
# shellcheck disable=SC2154  # LAB_NAME and CHECKS are provided by the caller
#
# Shared driver for a lab's guided `diagnose` action. The caller (a lab's
# diagnose.sh) sets LAB_NAME (via lib.sh) and CHECKS, then calls run_diagnosis.
# CHECKS entries are "layer title|teaching hint|check_function"; each check
# function returns 0 (ok) or 1 (fail) and may echo short indented evidence.
# Diagnosis is bottom-up and stops (optionally) at the lowest failing layer —
# it points at the area of the problem without naming an injected fault, so it
# complements the "mystery" break mode.

LAB_SHORT="${LAB_NAME%-lab}"

dx_ok()   { printf '       [ ok ] %s\n' "$1"; }
dx_fail() { printf '       [FAIL] %s\n' "$1"; }

run_diagnosis() {
  local total=${#CHECKS[@]} i=1 entry title hint fn first_fail=""
  echo
  echo "Guided diagnosis of ${LAB_NAME} (bottom-up, layer by layer)"
  echo "════════════════════════════════════════════════════════════"

  for entry in "${CHECKS[@]}"; do
    title="${entry%%|*}"
    hint="${entry#*|}"; hint="${hint%%|*}"
    fn="${entry##*|}"
    printf '[%d/%d] %s\n' "${i}" "${total}" "${title}"

    if "${fn}"; then
      dx_ok "${title}"
    else
      dx_fail "${title}"
      echo "       → ${hint}"
      if [[ -z "${first_fail}" ]]; then
        first_fail="${title}"
        echo "       → This is the lowest failing layer; investigate here first."
        echo
        prompt_yes_no "Continue through the remaining layers anyway?" || {
          echo
          break
        }
      fi
    fi
    ((i++))
  done

  echo "════════════════════════════════════════════════════════════"
  if [[ -n "${first_fail}" ]]; then
    echo "Lowest failing layer: ${first_fail}"
    echo "Start there. When you are done, restore with: ./lab.sh ${LAB_SHORT} heal"
    return 1
  fi
  echo "All layers passed; ${LAB_NAME} looks healthy."
}
