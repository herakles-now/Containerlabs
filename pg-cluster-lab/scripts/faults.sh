#!/usr/bin/env bash
# shellcheck disable=SC2034  # FAULTS is consumed by the shared fault driver
#
# pg-cluster-lab fault catalogue. Sourced by break.sh and heal.sh. Each fault_*
# function applies its change silently; the driver prints the user-facing text.
# The faults are deliberately distinct teaching cases: a network partition, a
# primary outage (no automatic failover without Patroni/repmgr) and a paused
# WAL replay (the standby still receives WAL but stops applying it).

FAULTS=(
  "partition-pg3|the switch drops pg3's link, so pg3 is partitioned from the primary|fault_partition_pg3"
  "stop-primary|the primary (pg1) is stopped — writes fail and replication halts|fault_stop_primary"
  "pause-replay-pg2|pg2 still receives WAL but stops replaying it, so its reads go stale|fault_pause_replay_pg2"
  "break-archiving|the primary's archive_command is broken, so WAL piles up and never reaches the pgBackRest repo|fault_break_archiving"
)

fault_partition_pg3() {
  # Drop pg3's bridge port on the switch: pg3 keeps running but can no longer
  # reach the primary, so its walreceiver disconnects and the slot goes inactive.
  run_on sw ip link set eth3 down >/dev/null 2>&1
}

fault_stop_primary() {
  run_on pg1 su postgres -c "pg_ctl -D /pgdata -m fast -w -t 30 stop" >/dev/null 2>&1
}

fault_pause_replay_pg2() {
  run_on pg2 psql -U postgres -h /var/run/postgresql -tAc "SELECT pg_wal_replay_pause()" >/dev/null 2>&1
}

fault_break_archiving() {
  # Point archiving at a command that always fails: WAL can no longer be pushed
  # to the pgBackRest repo, so it accumulates in pg_wal on the primary.
  run_on pg1 psql -U postgres -h /var/run/postgresql -tAc "ALTER SYSTEM SET archive_command = '/bin/false'" >/dev/null 2>&1
  run_on pg1 psql -U postgres -h /var/run/postgresql -tAc "SELECT pg_reload_conf()" >/dev/null 2>&1
}
