#!/usr/bin/env bash
# shellcheck disable=SC2034  # lab variables below are consumed by sourcing scripts

# Lab-specific configuration. Generic helpers (privilege handling,
# docker/containerlab wrappers, run_on, require_container, ...) live in
# ../../scripts/common.sh.
LAB_NAME="pg-cluster-lab"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPOLOGY_FILE="${PROJECT_DIR}/pg-cluster-lab.clab.yml"
IMAGE_NAME="pg-cluster-lab:latest"

# All nodes, plus the database roles. sw is the L2 switch; pg1 is the primary,
# pg2/pg3 are the streaming standbys and backup is the pgBackRest repo host.
NODES=(pg1 pg2 pg3 backup sw)
PRIMARY="pg1"
STANDBYS=(pg2 pg3)
PRIMARY_IP="10.10.0.1"

# pg2 follows the primary immediately; pg3 is a time-delayed standby that
# applies WAL APPLY_DELAY late (it still receives WAL in real time).
IMMEDIATE_STANDBY="pg2"
DELAYED_STANDBY="pg3"
APPLY_DELAY="3min"

# Dedicated pgBackRest repository host; the stanza's data files are read from
# the immediate standby (backup-standby), the repo lives on BACKUP_NODE.
BACKUP_NODE="backup"
STANZA="main"

# Where each node keeps its data directory and unix socket (set in the config
# start scripts; reused by the diagnostic/heal scripts).
PGDATA="/pgdata"
SOCKDIR="/var/run/postgresql"

# shellcheck source=../../scripts/common.sh
source "${PROJECT_DIR}/../scripts/common.sh"

# Run a SQL query on a node's local PostgreSQL over the unix socket and print
# the bare result (tuples only, unaligned). Local connections use trust auth, so
# no password is needed. Usage: psql_on pg1 "SELECT pg_is_in_recovery()".
psql_on() {
  local node="$1"
  shift
  run_on "${node}" psql -U postgres -h "${SOCKDIR}" -tAqc "$*"
}

# Run a pgBackRest command on the repository host as the postgres user, against
# the lab's stanza. Usage: pgbackrest_repo info   /   pgbackrest_repo --type=diff backup
pgbackrest_repo() {
  run_on "${BACKUP_NODE}" su postgres -c "pgbackrest --stanza=${STANZA} $*"
}
