#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

psql_table() {
  local node="$1" sql="$2"
  run_on "${node}" psql -U postgres -h "${SOCKDIR}" -x -c "${sql}" || true
}

# --- Primary ---
if docker_cmd inspect "$(container_name pg1)" >/dev/null 2>&1; then
  echo
  echo "################################################################"
  echo "Primary: pg1"
  echo "===== pg1: role (f = primary, t = standby) ====="
  psql_on pg1 "SELECT pg_is_in_recovery() AS in_recovery" || true
  echo "===== pg1: connected standbys (pg_stat_replication) ====="
  psql_table pg1 "SELECT application_name, client_addr, state, sync_state, write_lag, replay_lag FROM pg_stat_replication"
  echo "===== pg1: replication slots ====="
  psql_table pg1 "SELECT slot_name, slot_type, active, restart_lsn FROM pg_replication_slots"
  echo "===== pg1: current WAL position ====="
  psql_on pg1 "SELECT pg_current_wal_lsn()" || true
  echo "===== pg1: WAL archiver (pgBackRest archive-push to the repo host) ====="
  psql_table pg1 "SELECT archived_count, last_archived_wal, failed_count, last_failed_wal FROM pg_stat_archiver"
fi

# --- pgBackRest repository (dedicated backup host) ---
if docker_cmd inspect "$(container_name "${BACKUP_NODE}")" >/dev/null 2>&1; then
  echo
  echo "################################################################"
  echo "pgBackRest repository host: ${BACKUP_NODE}"
  echo "===== ${BACKUP_NODE}: pgBackRest info ====="
  pgbackrest_repo info || true
fi

# --- Standbys ---
for node in "${STANDBYS[@]}"; do
  if ! docker_cmd inspect "$(container_name "${node}")" >/dev/null 2>&1; then
    echo "Container $(container_name "${node}") is not present; skipping." >&2
    continue
  fi
  echo
  echo "################################################################"
  echo "Standby: ${node}"
  echo "===== ${node}: role (t = standby) and configured apply delay ====="
  psql_on "${node}" "SELECT pg_is_in_recovery() AS in_recovery" || true
  psql_on "${node}" "SHOW recovery_min_apply_delay" || true
  echo "===== ${node}: WAL receiver (link to the primary) ====="
  psql_table "${node}" "SELECT status, sender_host, slot_name, received_lsn, latest_end_lsn FROM pg_stat_wal_receiver"
  echo "===== ${node}: receive vs replay position and replay paused? ====="
  psql_on "${node}" "SELECT pg_last_wal_receive_lsn() AS received, pg_last_wal_replay_lsn() AS replayed, pg_is_wal_replay_paused() AS replay_paused" || true
  echo "===== ${node}: replication lag behind the primary (seconds) ====="
  psql_on "${node}" "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::int AS lag_seconds" || true
done
