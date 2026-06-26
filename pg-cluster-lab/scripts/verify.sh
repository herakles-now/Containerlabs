#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

failures=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }

debug_node() {
  local node="$1"
  echo "===== Debug output: ${node} =====" >&2
  run_on "${node}" ip -br address >&2 || true
  if [[ "${node}" == pg* ]]; then
    psql_on "${node}" "SELECT pg_is_in_recovery()" >&2 || true
    psql_on "${node}" "SELECT * FROM pg_stat_replication" >&2 || true
    psql_on "${node}" "SELECT * FROM pg_stat_wal_receiver" >&2 || true
  fi
}

require_command docker

for node in "${NODES[@]}"; do
  if require_container "${node}"; then
    pass "Container $(container_name "${node}") is running"
  else
    fail "Container $(container_name "${node}") is unavailable"
  fi
done

if (( failures > 0 )); then
  exit 1
fi

# 1. The primary accepts writes (not in recovery); both standbys are read-only.
if [[ "$(psql_on pg1 "SELECT pg_is_in_recovery()")" == "f" ]]; then
  pass "pg1 is the primary (not in recovery)"
else
  fail "pg1 is not acting as the primary"
fi

for standby in "${STANDBYS[@]}"; do
  if [[ "$(psql_on "${standby}" "SELECT pg_is_in_recovery()")" == "t" ]]; then
    pass "${standby} is a read-only standby (in recovery)"
  else
    fail "${standby} is not in standby/recovery mode"
  fi
done

# 2. The primary has a walsender streaming to each standby.
repl_count="$(psql_on pg1 "SELECT count(*) FROM pg_stat_replication")"
if [[ "${repl_count}" == "2" ]]; then
  pass "pg1 has 2 streaming standbys connected"
else
  fail "pg1 reports ${repl_count:-0} streaming standbys (expected 2)"
fi

# 3. Both physical replication slots exist and are active.
active_slots="$(psql_on pg1 "SELECT count(*) FROM pg_replication_slots WHERE active")"
if [[ "${active_slots}" == "2" ]]; then
  pass "Both replication slots on pg1 are active"
else
  fail "pg1 has ${active_slots:-0} active replication slots (expected 2)"
fi

# 4. A write on the primary replicates promptly to the immediate standby (pg2).
marker="probe-$(date +%s)-${RANDOM}"
psql_on pg1 "CREATE TABLE IF NOT EXISTS lab_check (k text PRIMARY KEY, v text); INSERT INTO lab_check VALUES ('probe', '${marker}') ON CONFLICT (k) DO UPDATE SET v = excluded.v" >/dev/null

replicated=false
for _ in $(seq 1 30); do
  if [[ "$(psql_on "${IMMEDIATE_STANDBY}" "SELECT v FROM lab_check WHERE k='probe'" 2>/dev/null)" == "${marker}" ]]; then
    replicated=true
    break
  fi
  sleep 1
done
if [[ "${replicated}" == "true" ]]; then
  pass "Write on pg1 replicated promptly to ${IMMEDIATE_STANDBY}"
else
  fail "Write on pg1 did not replicate to ${IMMEDIATE_STANDBY}"
fi

# 5. The delayed standby (pg3) is configured to trail and still RECEIVES WAL in
#    real time — we do not wait out the apply delay here.
delay="$(psql_on "${DELAYED_STANDBY}" "SHOW recovery_min_apply_delay")"
if [[ "${delay}" == "${APPLY_DELAY}" ]]; then
  pass "${DELAYED_STANDBY} is a time-delayed standby (recovery_min_apply_delay=${delay})"
else
  fail "${DELAYED_STANDBY} apply delay is '${delay:-unset}', expected ${APPLY_DELAY}"
fi

wr_status="$(psql_on "${DELAYED_STANDBY}" "SELECT status FROM pg_stat_wal_receiver")"
if [[ "${wr_status}" == "streaming" ]]; then
  pass "${DELAYED_STANDBY} is receiving WAL from the primary in real time (streaming)"
else
  fail "${DELAYED_STANDBY} is not receiving WAL (walreceiver status: ${wr_status:-none})"
fi

# 6. A write must be rejected on a standby (it is read-only).
if psql_on "${IMMEDIATE_STANDBY}" "CREATE TABLE should_fail (x int)" >/dev/null 2>&1; then
  fail "${IMMEDIATE_STANDBY} accepted a write but should be read-only"
else
  pass "${IMMEDIATE_STANDBY} correctly rejects writes (read-only standby)"
fi

# 7. pgBackRest: WAL archiving (pg1 -> repo host) is working and a full backup
#    exists in the repository on the dedicated backup host.
archived="$(psql_on pg1 "SELECT archived_count FROM pg_stat_archiver")"
if [[ -n "${archived}" && "${archived}" -gt 0 ]]; then
  pass "WAL archiving from pg1 to the repo host is working (archived_count=${archived})"
else
  fail "pg1 has not archived any WAL yet (archived_count=${archived:-0})"
fi

info="$(pgbackrest_repo info 2>/dev/null)"
if grep -q "status: ok" <<<"${info}"; then
  pass "pgBackRest stanza '${STANZA}' status is ok (repo on ${BACKUP_NODE})"
else
  fail "pgBackRest stanza '${STANZA}' is not healthy"
fi
if grep -q "full backup:" <<<"${info}"; then
  pass "pgBackRest has a full backup"
else
  fail "pgBackRest has no full backup"
fi

# 8. The backup was read from the standby. With backup-standby active pgBackRest
#    logs that it waited for replay on the standby; that line is our proof.
blog="$(run_on "${BACKUP_NODE}" cat /var/log/pgbackrest/${STANZA}-backup.log 2>/dev/null)"
if grep -qi "standby" <<<"${blog}"; then
  pass "Backup data was read from the standby (backup-standby)"
else
  fail "No evidence the backup used the standby (backup-standby)"
fi

if (( failures > 0 )); then
  echo "${failures} verification check(s) failed. Collecting diagnostics..." >&2
  for node in "${NODES[@]}"; do
    if docker_cmd inspect "$(container_name "${node}")" >/dev/null 2>&1; then
      debug_node "${node}"
    fi
  done
  exit 1
fi

echo "All PostgreSQL replication and pgBackRest checks passed."
