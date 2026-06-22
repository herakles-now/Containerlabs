#!/usr/bin/env bash
set -uo pipefail

# Entry point for the nat4-lab. Run without arguments for an interactive menu,
# or pass an action directly, e.g. `./lab.sh deploy`. The menu engine and the
# command dispatcher live in ../scripts/menu.sh.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_DIR}/scripts"
LAB_TITLE="nat4-lab"

# Ordered list of "action|script|description" entries. The menu, the usage
# text and the dispatcher are all generated from this single source. The four
# NAT cases each get explicit test/capture actions instead of a CASE flag.
ACTIONS=(
  "deploy|deploy.sh|Build, create bridges, deploy and configure"
  "build|build.sh|Build the lab image only"
  "configure|configure-all.sh|(Re)apply addresses, routes and nftables"
  "verify|test-all.sh|Run all four NAT scenario tests"
  "test-static|test-static-nat.sh|Test static NAT (L3 only)"
  "test-dynamic|test-dynamic-nat.sh|Test dynamic pool NAT"
  "test-forward|test-port-forward.sh|Test destination port forwarding"
  "test-pat|test-pat.sh|Test PAT (many-to-one)"
  "capture-static|capture-static-nat.sh|Live capture for static NAT"
  "capture-dynamic|capture-dynamic-nat.sh|Live capture for dynamic NAT"
  "capture-forward|capture-port-forward.sh|Live capture for port forwarding"
  "capture-pat|capture-pat.sh|Live capture for PAT"
  "state|show-state.sh|Show nftables and conntrack per gateway"
  "inspect|inspect-lab.sh|Show the containerlab and per-case state"
  "break|break.sh|Inject a fault (named or random) to diagnose"
  "diagnose|diagnose.sh|Guided, layer-by-layer diagnosis"
  "heal|heal.sh|Restore the lab to its known-good baseline"
  "config|edit-config.sh|Show the config and optionally edit + re-apply"
  "destroy|destroy.sh|Tear down the lab and host bridges"
  "clean|clean.sh|Tear down and remove the lab image"
)

# shellcheck source=../scripts/menu.sh
source "${PROJECT_DIR}/../scripts/menu.sh"
lab_dispatch "$@"
