#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=faults.sh
source "${SCRIPT_DIR}/faults.sh"
# shellcheck source=../../scripts/fault-driver.sh
source "${PROJECT_DIR}/../scripts/fault-driver.sh"

require_command docker

echo "Restoring the known-good configuration..."

# Bring every switch port back up (undoes the network partition).
for port in eth1 eth2 eth3 eth4; do
  run_on sw ip link set "${port}" up >/dev/null 2>&1 || true
done

# Make sure the primary is running again (pg_ctl start is a no-op if it is).
run_on pg1 su postgres -c "pg_ctl -D /pgdata -l /pgdata/server.log -w -t 30 start" >/dev/null 2>&1 || true

# Resume WAL replay on both standbys (no-op if they were not paused).
for standby in "${STANDBYS[@]}"; do
  run_on "${standby}" psql -U postgres -h "${SOCKDIR}" -tAc "SELECT pg_wal_replay_resume()" >/dev/null 2>&1 || true
done

# Restore the pgBackRest archive_command in case break-archiving was injected.
run_on pg1 psql -U postgres -h "${SOCKDIR}" -tAc \
  "ALTER SYSTEM SET archive_command = 'pgbackrest --stanza=${STANZA} archive-push %p'" >/dev/null 2>&1 || true
run_on pg1 psql -U postgres -h "${SOCKDIR}" -tAc "SELECT pg_reload_conf()" >/dev/null 2>&1 || true

# The standbys reconnect to the primary on their own; give them a moment.
sleep 3

reveal_fault
echo "pg-cluster-lab restored. Run './lab.sh pg-cluster verify' to confirm."
