#!/usr/bin/env bash
set -euo pipefail

# Dedicated pgBackRest repository host. It runs no PostgreSQL of its own; it
# reaches the database hosts over SSH (as the postgres user) and owns the repo
# under /var/lib/pgbackrest. Once pg1 (primary) and pg2 (standby) are up it
# creates the stanza and takes the first backup — read from the standby.

PRIMARY="10.10.0.1"
STANDBY="10.10.0.2"

# 1. Cluster network + ssh daemon
ip addr flush dev eth1
ip link set eth1 up
ip addr add 10.10.0.4/24 dev eth1
/usr/sbin/sshd

install -d -m 750 -o postgres -g postgres /var/lib/pgbackrest /var/log/pgbackrest

# 2. Wait until both database hosts are reachable over SSH and accept
#    connections (full paths: a non-interactive SSH PATH lacks /usr/local/bin).
ready() {
  su postgres -c "ssh -o ConnectTimeout=3 ${1} /usr/local/bin/pg_isready -h /var/run/postgresql -q"
}
for _ in $(seq 1 90); do
  if ready "${PRIMARY}" && ready "${STANDBY}"; then
    break
  fi
  sleep 2
done

# 3. Wait until pg2 is actually a streaming standby — backup-standby needs it to
#    replay up to the backup start LSN.
for _ in $(seq 1 60); do
  rec="$(su postgres -c "ssh ${STANDBY} /usr/local/bin/psql -U postgres -h /var/run/postgresql -tAc 'SELECT pg_is_in_recovery()'" 2>/dev/null || true)"
  [[ "${rec}" == "t" ]] && break
  sleep 2
done

# 4. Register the stanza, verify WAL archiving end to end, then take the first
#    full backup (read from the standby via backup-standby=y).
echo "Creating pgBackRest stanza 'main' and taking the initial backup from the standby..."
su postgres -c "pgbackrest --stanza=main stanza-create" || true
su postgres -c "pgbackrest --stanza=main check" || true
su postgres -c "pgbackrest --stanza=main --type=full backup" || true
su postgres -c "pgbackrest --stanza=main info" || true

ip -br addr
