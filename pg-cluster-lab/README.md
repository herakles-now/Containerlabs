# PostgreSQL 18 Cluster with pgBackRest (backup from standby) and a Delayed Standby

## Goal

This lab builds a three-node **PostgreSQL 18** cluster using streaming
replication, with a dedicated **pgBackRest** repository host that takes its
backups **from a standby**, and one **time-delayed standby**:

- `pg1` — **primary**, accepts writes, ships WAL to the standbys and archives
  WAL to the repository host.
- `pg2` — **hot standby**, applies WAL immediately (read-only). pgBackRest reads
  the backup's data files from here (`backup-standby`).
- `pg3` — **time-delayed hot standby**, receives WAL in real time but applies it
  `3min` late (`recovery_min_apply_delay`).
- `backup` — **dedicated pgBackRest repository host**. Runs no PostgreSQL of its
  own, so the backups survive the loss of `pg1`. Reaches the database hosts over
  SSH and runs the repo-side commands (stanza-create, backup, restore, info).
- `sw` — L2 switch joining everything onto one cluster subnet.

On it you can observe:

- **Backup from the standby**: with `backup-standby=y` pgBackRest copies the bulk
  data files from `pg2` to offload the primary. It *still* coordinates with the
  primary (`pg_backup_start/stop`, a few changed files) and waits for the
  standby to replay up to the backup start LSN — the backup log shows
  `wait for replay on the standby ...`. This is why a healthy, caught-up
  standby is required, and why the time-delayed `pg3` is deliberately **not**
  part of the stanza.
- **The backup is a whole-cluster backup**: reading it from the standby does not
  make it "the standby's backup" — it restores **pg1** perfectly. The `restore`
  action proves this by rebuilding pg1's data in a scratch directory and booting
  it.
- The standby `pg2` shows a committed write within milliseconds; `pg3` shows the
  same write only after the 3-minute delay — yet `pg3` has already **received**
  the WAL (receive vs apply are separate). A simple guard: an accidental
  `DROP TABLE` does not reach `pg3`'s data for three minutes.
- There is **no automatic failover**: if the primary dies, the standbys keep
  serving reads but nobody promotes itself (that needs Patroni/repmgr).

## Topology

```text
                         cluster subnet 10.10.0.0/24

   pg1 (primary)     pg2 (standby)    pg3 (delayed 3min)   backup (repo host)
   10.10.0.1         10.10.0.2        10.10.0.3            10.10.0.4
      |  eth1           |  eth1          |  eth1              |  eth1
      +-- sw:eth1       +-- sw:eth2      +-- sw:eth3          +-- sw:eth4
                \           |           /                    /
                 +--------- sw (L2 bridge br0) -------------+

   pg1 == WAL stream ==> pg2   (slot standby_pg2, applies immediately)
   pg1 == WAL stream ==> pg3   (slot standby_pg3, applies 3 min late)
   pg1 == archive_command (WAL) ==> backup repo
   backup == backup-standby: data files read from pg2, coordinated via pg1
```

## IP plan

| Node | Role | Address | Purpose |
|---|---|---:|---|
| pg1 | primary | 10.10.0.1/24 | accepts writes, streams WAL, archives WAL |
| pg2 | standby | 10.10.0.2/24 | read-only replica, immediate apply, backup source |
| pg3 | delayed standby | 10.10.0.3/24 | read-only replica, 3-minute apply delay |
| backup | pgBackRest repo host | 10.10.0.4/24 | owns the repo, runs backups/restores |
| sw | switch | – (L2 only) | bridges the cluster subnet |

The standbys connect to the primary at `10.10.0.1:5432` as the `replicator`
role. The backup host reaches the database hosts over SSH as the `postgres`
user. Containerlab's separate management network uses `172.31.251.0/24`.

> **Security note:** for passwordless pgBackRest-over-SSH the image bakes in a
> single shared SSH keypair so every node's `postgres` user trusts every other
> node. This is fine for a throwaway lab but must **never** be done in
> production — there you would use per-host keys (or TLS), a locked-down repo
> host and object storage for the repository.

## Prerequisites

- Linux host with Docker
- Containerlab
- `sudo` privileges for Containerlab

## Build and Deploy

```bash
./lab.sh deploy
```

Run `./lab.sh` without an action for an interactive menu. The scripts run as the
invoking user and escalate to `sudo` only where Containerlab requires root.

Deployment builds the image (PostgreSQL 18 + pgBackRest + OpenSSH + tools),
deploys the topology and waits for replication and the first backup. On boot:

- `pg1` initialises its data directory, enables `wal_level=replica` and WAL
  archiving (`archive_command = pgbackrest ... archive-push`), creates the
  `replicator` role and starts.
- `pg2` and `pg3` clone the primary with `pg_basebackup -R` and start as hot
  standbys; `pg3` adds `recovery_min_apply_delay = '3min'`.
- `backup` waits over SSH until `pg1` and `pg2` are ready and `pg2` is a
  streaming standby, then runs `pgbackrest stanza-create`, `check` and the first
  full backup — **read from the standby**.

Re-run the checks any time with:

```bash
./lab.sh verify
```

For a status snapshot or the full containerlab view:

```bash
./lab.sh state     # roles, apply delay, replication, slots, archiver, pgBackRest info
./lab.sh inspect   # containerlab graph/inventory plus the per-node state
```

### Backups and restore

```bash
./lab.sh backup            # differential backup read from the standby
./lab.sh backup full       # or: full / incr
./lab.sh restore           # prove pg1 is restorable (safe scratch restore)
```

`backup` runs on the repo host with `backup-standby=y`, so the data is pulled
from `pg2`. `restore` proves the primary is recoverable **without touching the
live cluster**: it restores the latest backup into a scratch directory on the
repo host, confirms the restored data has the same database system identifier as
the live `pg1`, and boots a throwaway instance from it.

A real in-place restore of `pg1` would instead be, on the primary:

```bash
pg_ctl -D /pgdata stop
pgbackrest --stanza=main --delta restore   # repo1-host points back at the backup node
pg_ctl -D /pgdata start
```

### Break things on purpose

```bash
./lab.sh break     # choose a fault, or "random" for a mystery
./lab.sh diagnose  # guided, layer-by-layer diagnosis with hints
./lab.sh heal      # restore the baseline (reveals a mystery fault)
./lab.sh config    # show the config (PostgreSQL + pgBackRest) and optionally edit
```

Faults:

- **`partition-pg3`** — the switch drops `pg3`'s port; it is cut off (walreceiver
  disconnects, slot inactive). `pg2` is unaffected.
- **`stop-primary`** — `pg1` is shut down. Writes fail, `pg_stat_replication`
  empties, yet both standbys still answer reads. No automatic failover.
- **`pause-replay-pg2`** — `pg2` keeps receiving WAL but stops applying it; its
  reads go stale while the network and walreceiver stay healthy.
- **`break-archiving`** — the primary's `archive_command` is pointed at a failing
  command, so WAL can no longer reach the repo and piles up in `pg_wal`.
  Replication is fine; only archiving/backups break.

`diagnose` works bottom-up — containers, cluster network, postmaster up,
primary/standby roles, streaming connections, WAL replay/receive, repo host &
SSH, backups & archiving — and stops at the lowest failing layer with a hint.
The delayed `pg3` is *expected* to trail, so it is only flagged if it stops
**receiving** WAL.

## Tests / things to try

### 1. See the delay in action

```bash
docker exec -it clab-pg-cluster-lab-pg1 psql -U postgres -c "CREATE TABLE t (id int); INSERT INTO t VALUES (42)"
docker exec -it clab-pg-cluster-lab-pg2 psql -U postgres -c "SELECT * FROM t"   # 42 at once
docker exec -it clab-pg-cluster-lab-pg3 psql -U postgres -c "SELECT * FROM t"   # absent for ~3 min
docker exec -it clab-pg-cluster-lab-pg3 psql -U postgres -c "SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()"
```

### 2. pgBackRest on the repo host

```bash
docker exec -it clab-pg-cluster-lab-backup su postgres -c "pgbackrest --stanza=main info"
# proof the data came from the standby:
docker exec -it clab-pg-cluster-lab-backup grep -i "replay on the standby" /var/log/pgbackrest/main-backup.log
```

### 3. WAL archiving from the primary

```bash
docker exec -it clab-pg-cluster-lab-pg1 \
  psql -U postgres -c "SELECT archived_count, last_archived_wal, failed_count FROM pg_stat_archiver"
```

## Tear Down the Lab

```bash
./lab.sh destroy
```

`./lab.sh clean` additionally removes the local `pg-cluster-lab:latest` image.
