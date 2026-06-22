#!/usr/bin/env bash
set -uo pipefail

# Entry point for the bgp-lab. Run without arguments for an interactive menu,
# or pass an action directly, e.g. `./lab.sh deploy`. The menu engine and the
# command dispatcher live in ../scripts/menu.sh.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_DIR}/scripts"
LAB_TITLE="bgp-lab"

# Ordered list of "action|script|description" entries. The menu, the usage
# text and the dispatcher are all generated from this single source.
ACTIONS=(
  "deploy|deploy.sh|Deploy the lab, configure it and verify"
  "configure|configure.sh|(Re)apply the Linux and BGP configuration"
  "verify|verify.sh|Run all verification checks"
  "routes|show-routes.sh|Show BGP summaries and routes"
  "state|show-state.sh|Show per-router BGP and routing state"
  "inspect|inspect-lab.sh|Show the containerlab and per-router state"
  "break|break.sh|Inject a fault (named or random) to diagnose"
  "heal|heal.sh|Restore the lab to its known-good baseline"
  "config|edit-config.sh|Show the config and optionally edit + re-apply"
  "prefer-r3|prefer-r3-to-r5.sh|Apply the Local-Preference policy on R1"
  "reset-policy|reset-policy.sh|Remove the Local-Preference policy"
  "destroy|destroy.sh|Tear the lab down"
)

# shellcheck source=../scripts/menu.sh
source "${PROJECT_DIR}/../scripts/menu.sh"
lab_dispatch "$@"
