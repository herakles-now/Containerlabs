#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

if ! require_container pg1; then
  echo "Deploy the lab first: ./lab.sh pg-cluster deploy" >&2
  exit 1
fi

echo "===== pg1: effective replication settings ====="
psql_on pg1 "SELECT name, setting FROM pg_settings WHERE name IN
  ('wal_level','max_wal_senders','max_replication_slots','hot_standby',
   'synchronous_commit','listen_addresses')" || true
echo
echo "===== pg1: host-based authentication rules (pg_hba) ====="
psql_on pg1 "SELECT type, database, user_name, address, auth_method
  FROM pg_hba_file_rules WHERE database <> '{all}' OR user_name <> '{all}'" || true
echo
echo "===== pgBackRest stanza (repo host: ${BACKUP_NODE}) ====="
pgbackrest_repo info || true

pgbackrest_conf="${PROJECT_DIR}/pgbackrest/backup.conf"
echo
echo "The primary's PostgreSQL config lives inside the pg1 container:"
echo "  ${PGDATA}/postgresql.conf   (server settings)"
echo "  ${PGDATA}/pg_hba.conf       (client/replication access rules)"
echo "The pgBackRest configs are host files mounted into the containers:"
echo "  ${PROJECT_DIR}/pgbackrest/pg1.conf      (primary)"
echo "  ${PROJECT_DIR}/pgbackrest/pg2.conf      (standby / backup source)"
echo "  ${pgbackrest_conf}   (repo host, backup-standby)"
echo

# An interactive editor needs a TTY, so go straight to docker exec -it.
if prompt_yes_no "Open pg1's pg_hba.conf in vi inside the container?"; then
  docker_cmd exec -it "$(container_name pg1)" vi "${PGDATA}/pg_hba.conf"
  if prompt_yes_no "Reload pg1's configuration now (SELECT pg_reload_conf())?"; then
    psql_on pg1 "SELECT pg_reload_conf()" || true
    echo "Configuration reloaded. Re-check with: ./lab.sh pg-cluster state"
  fi
fi

if prompt_yes_no "Open the repo host's pgBackRest config (${pgbackrest_conf}) in ${EDITOR:-vi}?"; then
  "${EDITOR:-vi}" "${pgbackrest_conf}"
  echo "Saved. The change is live on ${BACKUP_NODE} (bind mount); re-run a backup with:"
  echo "  ./lab.sh pg-cluster backup"
fi
