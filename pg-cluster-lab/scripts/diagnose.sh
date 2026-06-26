#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=../../scripts/diagnose-driver.sh
source "${PROJECT_DIR}/../scripts/diagnose-driver.sh"

require_command docker

check_containers() {
  local n status=0
  for n in "${NODES[@]}"; do
    if [[ "$(docker_cmd inspect -f '{{.State.Running}}' "$(container_name "${n}")" 2>/dev/null)" != "true" ]]; then
      echo "         ${n} is not running"; status=1
    fi
  done
  return "${status}"
}

check_network() {
  local n status=0
  for n in "${STANDBYS[@]}"; do
    if ! run_on "${n}" ping -c 1 -W 1 "${PRIMARY_IP}" >/dev/null 2>&1; then
      echo "         ${n} cannot reach the primary (${PRIMARY_IP}) — link/partition?"; status=1
    fi
  done
  return "${status}"
}

check_postgres_up() {
  local n status=0
  for n in pg1 "${STANDBYS[@]}"; do
    if ! run_on "${n}" pg_isready -U postgres -h "${SOCKDIR}" >/dev/null 2>&1; then
      echo "         ${n}: PostgreSQL is not accepting connections"; status=1
    fi
  done
  return "${status}"
}

check_roles() {
  local status=0 rec
  rec="$(psql_on pg1 "SELECT pg_is_in_recovery()" 2>/dev/null)"
  [[ "${rec}" == "f" ]] || { echo "         pg1 is not the primary (pg_is_in_recovery=${rec:-?})"; status=1; }
  local n
  for n in "${STANDBYS[@]}"; do
    rec="$(psql_on "${n}" "SELECT pg_is_in_recovery()" 2>/dev/null)"
    [[ "${rec}" == "t" ]] || { echo "         ${n} is not in standby mode (pg_is_in_recovery=${rec:-?})"; status=1; }
  done
  return "${status}"
}

check_replication() {
  local status=0 cnt connected
  cnt="$(psql_on pg1 "SELECT count(*) FROM pg_stat_replication" 2>/dev/null)"
  if [[ "${cnt}" != "2" ]]; then
    echo "         pg1 has ${cnt:-0} streaming standby(s) connected, expected 2"
    connected="$(psql_on pg1 "SELECT string_agg(client_addr::text, ', ') FROM pg_stat_replication" 2>/dev/null)"
    echo "         currently streaming to: ${connected:-none}"
    status=1
  fi
  return "${status}"
}

check_replay() {
  local status=0 paused lag wr
  # The immediate standby must apply WAL promptly and not be paused.
  paused="$(psql_on "${IMMEDIATE_STANDBY}" "SELECT pg_is_wal_replay_paused()" 2>/dev/null)"
  if [[ "${paused}" == "t" ]]; then
    echo "         ${IMMEDIATE_STANDBY}: WAL replay is PAUSED — it receives WAL but reads are stale"; status=1
  fi
  lag="$(psql_on "${IMMEDIATE_STANDBY}" "SELECT COALESCE(EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::int, 0)" 2>/dev/null)"
  if [[ -n "${lag}" && "${lag}" -gt 30 ]]; then
    echo "         ${IMMEDIATE_STANDBY}: replication lag is ${lag}s behind the primary"; status=1
  fi
  # The delayed standby trails on purpose, but it must still be RECEIVING WAL.
  wr="$(psql_on "${DELAYED_STANDBY}" "SELECT status FROM pg_stat_wal_receiver" 2>/dev/null)"
  if [[ "${wr}" != "streaming" ]]; then
    echo "         ${DELAYED_STANDBY}: not receiving WAL (walreceiver=${wr:-none}) — delay is fine, a stopped receiver is not"; status=1
  fi
  return "${status}"
}

check_repo_host() {
  local status=0
  if [[ "$(docker_cmd inspect -f '{{.State.Running}}' "$(container_name "${BACKUP_NODE}")" 2>/dev/null)" != "true" ]]; then
    echo "         ${BACKUP_NODE} (pgBackRest repo host) is not running"; return 1
  fi
  # The repo host must be able to reach both database hosts over SSH.
  run_on "${BACKUP_NODE}" su postgres -c "ssh -o ConnectTimeout=3 ${PRIMARY_IP} true" >/dev/null 2>&1 ||
    { echo "         ${BACKUP_NODE} cannot SSH to the primary (${PRIMARY_IP})"; status=1; }
  run_on "${BACKUP_NODE}" su postgres -c "ssh -o ConnectTimeout=3 10.10.0.2 true" >/dev/null 2>&1 ||
    { echo "         ${BACKUP_NODE} cannot SSH to the standby (10.10.0.2)"; status=1; }
  return "${status}"
}

check_backups() {
  local status=0 archived info
  archived="$(psql_on pg1 "SELECT archived_count FROM pg_stat_archiver" 2>/dev/null)"
  if [[ -z "${archived}" || "${archived}" -eq 0 ]]; then
    echo "         pg1: no WAL has been archived (pgBackRest archive-push)"; status=1
  fi
  info="$(pgbackrest_repo info 2>/dev/null)"
  grep -q "status: ok" <<<"${info}" || { echo "         pgBackRest stanza '${STANZA}' status is not ok"; status=1; }
  grep -q "full backup:" <<<"${info}" || { echo "         pgBackRest has no full backup yet"; status=1; }
  if ! pgbackrest_repo --archive-timeout=15 check >/dev/null 2>&1; then
    echo "         pgBackRest check failed — WAL archiving to the repo is broken"; status=1
  fi
  return "${status}"
}

CHECKS=(
  "Containers running|A node is down — deploy or restart the lab.|check_containers"
  "Cluster network|A standby cannot reach the primary; suspect a partitioned switch port (ip link).|check_network"
  "PostgreSQL up|A postmaster is down; check 'pg_ctl status' and the server log. The primary being down stops all writes (no automatic failover).|check_postgres_up"
  "Primary/standby roles|Roles are wrong; pg1 must be the primary and pg2/pg3 standbys (pg_is_in_recovery).|check_roles"
  "Streaming connections|A standby's walsender is missing on pg1; check 'pg_stat_replication' and 'pg_stat_wal_receiver' on the standby.|check_replication"
  "WAL replay & receive|pg2 must apply WAL promptly (not paused/lagging); pg3 trails on purpose but must still receive WAL. Check pg_is_wal_replay_paused() and pg_stat_wal_receiver.|check_replay"
  "Repo host & SSH|The pgBackRest repo host is down or cannot reach the database hosts over SSH; backups/archiving depend on it. Check the backup container and SSH.|check_repo_host"
  "Backups & archiving|WAL is not reaching the pgBackRest repo or no backup exists; check archive_command, 'pgbackrest check' and 'pgbackrest info' on the repo host.|check_backups"
)

run_diagnosis
