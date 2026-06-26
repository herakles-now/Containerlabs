#!/usr/bin/env bash
set -euo pipefail

# Primary node: owns the cluster, accepts writes and streams WAL to the
# standbys. Initialises its data directory once, starts PostgreSQL, creates the
# replication role and archives WAL to the pgBackRest repo host. The repo-side
# commands (stanza-create, backup) run on the backup host, not here.

PGDATA="/pgdata"
SOCKDIR="/var/run/postgresql"

# 0. SSH so the backup host can reach this primary (pgBackRest off-host mode).
/usr/sbin/sshd

# 1. Cluster network
ip addr flush dev eth1
ip link set eth1 up
ip addr add 10.10.0.1/24 dev eth1

# 2. Make sure the data and socket directories exist and are owned by postgres.
#    PGDATA must be 0700/0750 or the postmaster refuses to start.
install -d -o postgres -g postgres "${SOCKDIR}"
install -d -m 700 -o postgres -g postgres "${PGDATA}"

# 3. Initialise the primary's data directory exactly once
if [ ! -s "${PGDATA}/PG_VERSION" ]; then
  rm -rf "${PGDATA:?}"/*
  su postgres -c "initdb -D ${PGDATA} -U postgres --auth-host=scram-sha-256 --auth-local=trust"

  cat >>"${PGDATA}/postgresql.conf" <<EOF

# --- pg-cluster lab: primary settings ---
listen_addresses = '*'
unix_socket_directories = '${SOCKDIR}'
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
hot_standby = on
synchronous_commit = on
password_encryption = scram-sha-256

# WAL archiving to the pgBackRest repository on the backup host (over SSH).
archive_mode = on
archive_command = 'pgbackrest --stanza=main archive-push %p'
EOF

  cat >>"${PGDATA}/pg_hba.conf" <<'EOF'

# --- pg-cluster lab: allow the cluster subnet ---
host    replication   replicator   10.10.0.0/24   scram-sha-256
host    all           all          10.10.0.0/24   scram-sha-256
EOF
fi

# 4. Start PostgreSQL
su postgres -c "pg_ctl -D ${PGDATA} -l ${PGDATA}/server.log -w -t 30 start"

# 5. Create the replication role used by the standbys (idempotent). The
#    standbys create their own replication slots via pg_basebackup -C.
su postgres -c "psql -U postgres -h ${SOCKDIR} -v ON_ERROR_STOP=1" <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replicator') THEN
    CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replpass';
  END IF;
END
$$;
SQL

su postgres -c "psql -U postgres -h ${SOCKDIR}" <<'SQL'
SELECT pg_is_in_recovery() AS in_recovery;
SQL

# The pgBackRest stanza-create and the initial backup are driven from the
# backup (repository) host once both pg1 and pg2 are up — see configs/backup.sh.

ip -br addr
