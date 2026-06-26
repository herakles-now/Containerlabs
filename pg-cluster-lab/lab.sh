#!/usr/bin/env bash
set -uo pipefail

# Entry point for the pg-cluster-lab. Run without arguments for an interactive
# menu, or pass an action directly, e.g. `./lab.sh deploy`. The menu engine and
# the command dispatcher live in ../scripts/menu.sh.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_DIR}/scripts"
LAB_TITLE="pg-cluster-lab"

# Ordered list of "action|script|description" entries. The menu, the usage
# text and the dispatcher are all generated from this single source.
ACTIONS=(
  "deploy|deploy.sh|Build the image, deploy the lab and verify"
  "build|build.sh|Build the lab image only"
  "verify|verify.sh|Run all replication checks (roles, walsenders, data)"
  "state|show-state.sh|Show primary/standby roles, replication and lag"
  "backup|backup.sh|Take a pgBackRest backup (read from the standby)"
  "restore|restore.sh|Prove pg1 is restorable from the backup (scratch restore)"
  "inspect|inspect-lab.sh|Show the containerlab and per-node state"
  "break|break.sh|Inject a fault (named or random) to diagnose"
  "diagnose|diagnose.sh|Guided, layer-by-layer diagnosis"
  "heal|heal.sh|Restore the cluster to its known-good baseline"
  "config|edit-config.sh|Show the primary config and optionally edit + reload"
  "destroy|destroy.sh|Tear the lab down"
  "clean|clean.sh|Tear down and remove the lab image"
)

# shellcheck source=../scripts/menu.sh
source "${PROJECT_DIR}/../scripts/menu.sh"
lab_dispatch "$@"
