#!/usr/bin/env bash
set -uo pipefail

# Entry point for the ipsec-lab. Run without arguments for an interactive menu,
# or pass an action directly, e.g. `./lab.sh deploy`. The menu engine and the
# command dispatcher live in ../scripts/menu.sh.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_DIR}/scripts"
LAB_TITLE="ipsec-lab"

# Ordered list of "action|script|description" entries. The menu, the usage
# text and the dispatcher are all generated from this single source.
ACTIONS=(
  "deploy|deploy.sh|Build the image, deploy the lab and verify"
  "build|build.sh|Build the lab image only"
  "verify|verify.sh|Trigger the tunnel and run all checks"
  "state|show-state.sh|Show IPsec SAs, policies and routing"
  "inspect|inspect-lab.sh|Show the containerlab and per-node state"
  "transit-watch|transit-watch.sh|Follow the transit capture (IKE/ESP)"
  "destroy|destroy.sh|Tear the lab down"
  "clean|clean.sh|Tear down and remove the lab image"
)

# shellcheck source=../scripts/menu.sh
source "${PROJECT_DIR}/../scripts/menu.sh"
lab_dispatch "$@"
