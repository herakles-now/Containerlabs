#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

if ! require_container "${BACKUP_NODE}"; then
  echo "Deploy the lab first: ./lab.sh pg-cluster deploy" >&2
  exit 1
fi

# Prove the primary (pg1) is restorable from the standby-sourced backup WITHOUT
# touching the live cluster: restore into a scratch directory on the repo host,
# confirm it is genuinely pg1's data (same system identifier) and boot a
# throwaway instance from it. The real in-place procedure is in the README.

SCRATCH="/var/lib/pg1-restore"
SOCK="/tmp/pg1-restore-sock"
PORT=5433

echo "===== Verifying repository integrity ====="
pgbackrest_repo verify || echo "(pgbackrest verify unavailable or reported issues; continuing)"

echo
echo "===== Restoring pg1 into a scratch dir on ${BACKUP_NODE} (${SCRATCH}) ====="
# --reset-pg1-host makes pgBackRest restore locally on the repo host instead of
# pushing the restore to the remote primary. The scratch dir lives under
# /var/lib (root-owned), so create it as root and hand it to postgres.
run_on "${BACKUP_NODE}" rm -rf "${SCRATCH}"
run_on "${BACKUP_NODE}" install -d -m 700 -o postgres -g postgres "${SCRATCH}"
# Default restore type: pgBackRest writes recovery.signal + a restore_command
# (archive-get from the local repo) so the throwaway instance can recover to a
# consistent point and open.
if ! run_on "${BACKUP_NODE}" su postgres -c \
  "pgbackrest --stanza=${STANZA} --reset-pg1-host --pg1-path=${SCRATCH} restore"; then
  echo "Restore failed." >&2
  exit 1
fi

echo
echo "===== Confirming the restored data really is pg1's cluster ====="
live_id="$(run_on pg1 su postgres -c "pg_controldata /pgdata" 2>/dev/null | grep -i 'system identifier' | tr -s ' ')"
rest_id="$(run_on "${BACKUP_NODE}" su postgres -c "pg_controldata ${SCRATCH}" 2>/dev/null | grep -i 'system identifier' | tr -s ' ')"
echo "  pg1 (live):     ${live_id}"
echo "  restored copy:  ${rest_id}"
if [[ -n "${rest_id}" && "${live_id}" == "${rest_id}" ]]; then
  echo "  -> same system identifier: the backup restores pg1's cluster."
else
  echo "  -> WARNING: system identifiers differ or could not be read." >&2
fi

echo
echo "===== Booting a throwaway instance from the restored copy (port ${PORT}) ====="
# Disable archiving/replication and move the socket+port so the throwaway cannot
# touch the repo or clash with anything.
run_on "${BACKUP_NODE}" su postgres -c "install -d -m 700 ${SOCK}; cat >>${SCRATCH}/postgresql.auto.conf <<EOF
archive_mode = off
listen_addresses = ''
port = ${PORT}
unix_socket_directories = '${SOCK}'
EOF"

if run_on "${BACKUP_NODE}" su postgres -c "pg_ctl -D ${SCRATCH} -l ${SCRATCH}/restore.log -w -t 60 start"; then
  echo -n "  databases in the restored cluster: "
  run_on "${BACKUP_NODE}" su postgres -c "psql -h ${SOCK} -p ${PORT} -U postgres -tAc \"SELECT string_agg(datname, ', ') FROM pg_database WHERE NOT datistemplate\"" || true
  run_on "${BACKUP_NODE}" su postgres -c "pg_ctl -D ${SCRATCH} -m fast -w -t 30 stop" >/dev/null 2>&1 || true
  echo "  -> the restored pg1 instance started and answered queries."
else
  echo "  Throwaway instance failed to start; see ${SCRATCH}/restore.log on ${BACKUP_NODE}." >&2
  run_on "${BACKUP_NODE}" su postgres -c "tail -20 ${SCRATCH}/restore.log" || true
fi

echo
echo "Cleaning up the scratch restore..."
run_on "${BACKUP_NODE}" su postgres -c "pg_ctl -D ${SCRATCH} -m immediate stop" >/dev/null 2>&1 || true
run_on "${BACKUP_NODE}" rm -rf "${SCRATCH}" "${SOCK}" || true
echo "Done. pg1 is restorable from the standby-sourced backup."
