#!/usr/bin/env bash
# shellcheck disable=SC2034  # lab variables below are consumed by sourcing scripts

# Lab-specific configuration. Generic helpers (privilege handling,
# docker/containerlab wrappers, run_on, require_container, ...) live in
# ../../scripts/common.sh.
LAB_NAME="ipsec-lab"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPOLOGY_FILE="${PROJECT_DIR}/ipsec-lab.clab.yml"
IMAGE_NAME="ipsec-lab:latest"
NODES=(pc1 r1 transit r2 pc2)

# shellcheck source=../../scripts/common.sh
source "${PROJECT_DIR}/../scripts/common.sh"
