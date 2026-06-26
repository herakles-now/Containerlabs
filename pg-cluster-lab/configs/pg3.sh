#!/usr/bin/env bash
set -euo pipefail

# Standby B: a TIME-DELAYED read-only hot standby. It streams WAL from the
# primary (pg1) in real time but waits recovery_min_apply_delay before applying
# it, so its data deliberately trails the primary by a fixed window — a simple
# guard against a bad write/DROP propagating instantly to every replica.

PGDATA="/pgdata"
SOCKDIR="/var/run/postgresql"
PRIMARY="10.10.0.1"
MYADDR="10.10.0.3"
SLOT="standby_pg3"

# 0. SSH (so the backup host could restore onto pg3 if ever needed).
/usr/sbin/sshd

# 1. Cluster network
ip addr flush dev eth1
ip link set eth1 up
ip addr add "${MYADDR}/24" dev eth1

# PGDATA must be 0700/0750 or the postmaster refuses to start; pg_basebackup
# restores into this directory without changing its mode.
install -d -o postgres -g postgres "${SOCKDIR}"
install -d -m 700 -o postgres -g postgres "${PGDATA}"

# 2. Let the walreceiver authenticate without an interactive password
echo "${PRIMARY}:5432:*:replicator:replpass" >/var/lib/postgresql/.pgpass
chown postgres:postgres /var/lib/postgresql/.pgpass
chmod 600 /var/lib/postgresql/.pgpass

# 3. Wait until the primary is up and the replication role can authenticate
for _ in $(seq 1 60); do
  if su postgres -c "PGPASSWORD=replpass psql -h ${PRIMARY} -U replicator -d postgres -tAc 'SELECT 1'" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# 4. Clone the primary once. -R writes standby.signal + primary_conninfo and
#    -S uses our own physical replication slot. The slot is created separately
#    and idempotently so a retried basebackup never trips over "slot exists".
if [ ! -s "${PGDATA}/PG_VERSION" ]; then
  rm -rf "${PGDATA:?}"/*
  su postgres -c "PGPASSWORD=replpass psql -h ${PRIMARY} -U replicator -d postgres -tAc \
    \"SELECT pg_create_physical_replication_slot('${SLOT}') WHERE NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name='${SLOT}')\"" || true
  for _ in $(seq 1 15); do
    if su postgres -c "PGPASSWORD=replpass pg_basebackup -h ${PRIMARY} -U replicator -D ${PGDATA} -X stream -S ${SLOT} -R -P"; then
      break
    fi
    echo "pg_basebackup failed, retrying..." >&2
    sleep 3
  done

  # Make this standby trail the primary by a fixed delay. recovery_min_apply_delay
  # holds back replay (not receive), so WAL still arrives in real time.
  printf "recovery_min_apply_delay = '3min'\n" >>"${PGDATA}/postgresql.auto.conf"
fi

# 5. Start the standby (read-only, hot standby — it follows pg1 with a delay)
su postgres -c "pg_ctl -D ${PGDATA} -l ${PGDATA}/server.log -w -t 30 start"

ip -br addr
su postgres -c "psql -U postgres -h ${SOCKDIR} -tAc 'SELECT pg_is_in_recovery()'"
