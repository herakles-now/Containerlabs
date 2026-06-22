# Four Classic NAT Cases with Containerlab and nftables

This lab makes NAT visible at packet level. Four fully isolated scenarios show which IPv4 address nftables changes, when a TCP port changes as well, and how the same connection appears from the inside and outside perspectives. The tests combine `tcpdump`, nftables counters, and Linux conntrack state.

## Requirements

- Linux host
- Docker
- Containerlab
- `sudo` privileges for bridges, network namespaces, and Containerlab

The common Alpine image contains Bash, iproute2, nftables, tcpdump, conntrack-tools, curl, iputils, BusyBox networking tools, and bind-tools.

## Quick Start

```bash
cd nat4-lab
./lab.sh deploy
./lab.sh verify
```

Run `./lab.sh` without an action for an interactive menu. The scripts run as the
invoking user and escalate to `sudo` only where bridges, namespaces, or
Containerlab require root.

`./lab.sh deploy` builds the image, creates eight isolated host bridges, deploys all containers, and configures addresses, routes, forwarding, and nftables. The configuration is repeatable:

```bash
./lab.sh configure
```

## The Four Cases

| Case | Mapping | Layer 3 | Layer 4 | Practical test |
|---|---|---:|---:|---|
| Static NAT | `10.10.1.10` ↔ `198.51.100.10` | yes | not intentionally | Source port 41000 is preserved |
| Dynamic NAT | `10.10.2.0/24` → pool `.10-.20` | yes | not intentionally | Two hosts receive different pool addresses |
| Port forwarding | `198.51.102.1:8080` → `10.10.3.10:80` | yes | yes | Destination address and port both change |
| PAT | `10.10.4.0/24` → `198.51.103.1` | yes | yes | Same outside address, different ports |

All outside networks use RFC 5737 documentation address space and are exclusively lab addresses.

### Static NAT: Layer 3 Without Intentional Layer-4 Translation

One fixed private address has one fixed public address. The test script forces TCP source port 41000. The inside capture shows `10.10.1.10:41000`, while the outside capture shows `198.51.100.10:41000`. The rule contains no port range and requests no port translation.

### Dynamic NAT: Addresses from a Pool

Conntrack selects an address from `198.51.101.10-198.51.101.20` for each new flow. Both internal hosts use source port 42000 in the test and can preserve it because they receive different public addresses. Linux NAT is stateful: if an identical five-tuple collision still occurs, conntrack may adjust a port. Completely port-free dynamic NAT therefore cannot be guaranteed for every possible traffic combination.

### Port Forwarding: Destination Address and Port

The outside client connects to `198.51.102.1:8080`. Prerouting changes the destination to `10.10.3.10:80`. The return path is translated automatically through the same conntrack entry. Because the inside server uses the NAT gateway as its default route, no additional masquerade rule is required.

### PAT: Many-to-One Using Ports

Two internal hosts simultaneously start the same destination flow with source port 43000. Both are translated to `198.51.103.1`. Because two identical public five-tuples cannot coexist, conntrack must change at least one outside port. This behavior makes PAT visibly different from address-only NAT.

## Tests

```bash
./lab.sh test-static
./lab.sh test-dynamic
./lab.sh test-forward
./lab.sh test-pat
```

Each test clears its NAT state, starts the appropriate HTTP server, captures both gateway interfaces, generates traffic, validates the expected tuples, and displays nftables and conntrack state. `eth1` is always inside and `eth2` is always outside.

`./lab.sh verify` is the standard lifecycle command and runs all four scenario tests.

## Live Captures

```bash
./lab.sh capture-static
```

Each capture first asks whether it should generate the matching test traffic itself once `tcpdump` is listening:

```text
Auto-generate the matching test traffic once the capture is up? [Y/n]
```

- Press Enter (or `y`) and the capture fires the scenario's flow for you and uses a short window. Nothing else is needed.
- Answer `n` to drive the traffic yourself; the capture then prints the exact command to run in a second terminal during the window, e.g.:

  ```bash
  ./lab.sh test-static
  ```

Other capture actions are `capture-dynamic`, `capture-forward`, and `capture-pat`. Override the window length with the `DURATION` environment variable (applies to both the auto and manual paths):

```bash
DURATION=60 ./lab.sh capture-pat
```

Lines marked `[INSIDE]` show packets before NAT on `eth1`; lines marked `[OUTSIDE]` show the corresponding flow after NAT on `eth2`.

## State and Diagnostics

```bash
./lab.sh state
./lab.sh inspect
docker exec clab-nat4-lab-pat-gw nft list table ip nat4
docker exec clab-nat4-lab-pat-gw conntrack -L -o extended
docker exec clab-nat4-lab-pat-gw ip -br address
```

Conntrack displays original and reply tuples. nftables makes the NAT decision for the first packet of a flow; later packets follow the stored conntrack mapping. Rules and state must therefore be examined together.

`./lab.sh inspect` adds the current Containerlab view on top of the per-scenario state: it prints the live graph, the deployed lab inventory, the node interfaces, and then the nftables, conntrack, IP address, and routing state for each NAT gateway.

## Limitations

- NAT is stateful and is not selected again for every packet.
- Static and dynamic NAT do not intentionally change Layer 4. Conntrack may still change ports when required to resolve a tuple collision.
- `masquerade` uses the current address of the outside interface. This is convenient for PAT but less explicit than a fixed `snat to` rule.
- Captures on Linux interfaces can show apparently invalid checksums because of checksum offloading. The address and port tuples remain meaningful.
- `tcpdump` shows the interface perspective. Conntrack additionally documents the logical original and reply directions.

## Cleanup

```bash
./lab.sh destroy
```

This removes the containers, veth links, generated Containerlab directory, and all eight host bridges. `./lab.sh clean` also removes the local `nat4-lab:latest` image.

More detail is available in [docs/topology.md](docs/topology.md), [docs/static-nat.md](docs/static-nat.md), [docs/dynamic-nat.md](docs/dynamic-nat.md), [docs/port-forwarding.md](docs/port-forwarding.md), and [docs/pat.md](docs/pat.md).
