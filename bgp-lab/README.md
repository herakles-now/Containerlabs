# FRR eBGP Containerlab

This project is a reproducible seven-AS eBGP lab built with Containerlab, Docker, and FRRouting (FRR). It demonstrates eBGP adjacency formation, route propagation, AS paths, transit autonomous systems, multihoming, BGP best-path selection, and Local Preference.

## Topology

```text
                         r1 (AS100)
                        /          \
                       /            \
                r2 (AS200)       r3 (AS400)
                       \           /  \
                        \         /    \
                         r5 (AS300)     r4 (AS500)
                                           \
                                            r6 (AS600)
                                               \
                                                r7 (AS700)
```

All connections are eBGP transit links. R5 is multihomed through R2 and R3. The R4-R6-R7 chain illustrates transit-AS behavior and propagation across multiple autonomous systems.

## AS and address plan

| Router | AS | Router ID | Internal prefix | `dummy0` address |
|---|---:|---|---|---|
| r1 | 100 | 1.1.1.1 | 10.1.0.0/16 | 10.1.0.1/16 |
| r2 | 200 | 2.2.2.2 | 10.2.0.0/16 | 10.2.0.1/16 |
| r3 | 400 | 3.3.3.3 | 10.4.0.0/16 | 10.4.0.1/16 |
| r4 | 500 | 4.4.4.4 | 10.5.0.0/16 | 10.5.0.1/16 |
| r5 | 300 | 5.5.5.5 | 10.3.0.0/16 | 10.3.0.1/16 |
| r6 | 600 | 6.6.6.6 | 10.6.0.0/16 | 10.6.0.1/16 |
| r7 | 700 | 7.7.7.7 | 10.7.0.0/16 | 10.7.0.1/16 |

| Link | Subnet | Endpoint A | Endpoint B |
|---|---|---|---|
| r1-r2 | 192.168.12.0/30 | r1 `eth1`: 192.168.12.1 | r2 `eth1`: 192.168.12.2 |
| r1-r3 | 192.168.13.0/30 | r1 `eth2`: 192.168.13.1 | r3 `eth1`: 192.168.13.2 |
| r2-r5 | 192.168.25.0/30 | r2 `eth2`: 192.168.25.1 | r5 `eth1`: 192.168.25.2 |
| r3-r5 | 192.168.35.0/30 | r3 `eth2`: 192.168.35.1 | r5 `eth2`: 192.168.35.2 |
| r3-r4 | 192.168.34.0/30 | r3 `eth3`: 192.168.34.1 | r4 `eth1`: 192.168.34.2 |
| r4-r6 | 192.168.46.0/30 | r4 `eth2`: 192.168.46.1 | r6 `eth1`: 192.168.46.2 |
| r6-r7 | 192.168.67.0/30 | r6 `eth2`: 192.168.67.1 | r7 `eth1`: 192.168.67.2 |

Containerlab uses the `clab-mgmt` network and `172.30.0.0/24` for management. Management addresses do not participate in BGP.

## Requirements and startup

Install Linux, Docker, and Containerlab. The user running the lab must be able to access the Docker daemon (membership in the `docker` group, or sudo access). From this directory, start the interactive menu:

```bash
./lab.sh
```

or run a single action directly:

```bash
./lab.sh deploy
```

The scripts run as your user and escalate to `sudo` only for the steps that genuinely need root (Containerlab manipulates host network namespaces and veth pairs). You may be prompted for your password once at the start.

The deployment action validates the required commands, deploys the topology, waits for FRR, applies the Linux and BGP configuration, and runs verification. It is safe to run the configuration again:

```bash
./lab.sh configure
./lab.sh verify
```

Destroy all lab containers and links with:

```bash
./lab.sh destroy
```

This project intentionally follows the requested `frrouting/frr:latest` image tag. That is convenient for learning but means a future image update can change FRR behavior or command output. For long-lived CI or course material, replace `latest` with a version or digest that has been tested in that environment.

## Testing and inspection

Run the complete test suite or display all control-plane routes:

```bash
./lab.sh verify
./lab.sh routes
```

The verification checks all containers and FRR instances, IPv4 forwarding and the `dummy0` connected route on every router, every BGP session, all seven prefixes on R1, both paths from R1 to R5, and bidirectional sourced pings between R1 and R7.

For a quick status snapshot or the full containerlab view, use:

```bash
./lab.sh state     # per-router BGP summary, BGP routes and kernel routes
./lab.sh inspect   # containerlab graph/inventory plus the per-router state
```

### Break things on purpose

```bash
./lab.sh break     # choose a fault, or "random" for a mystery
./lab.sh diagnose  # guided, layer-by-layer diagnosis with hints
./lab.sh heal      # restore the baseline (reveals a mystery fault)
./lab.sh config    # show the running-config and optionally edit + re-apply
```

Faults: `peer-shutdown` (R1's session to R3 is administratively down),
`as-mismatch` (R1 uses the wrong remote-as for R2), `withdraw-prefix` (R7 stops
originating 10.7.0.0/16). Inject one, then run `diagnose` (or `verify`/`state`)
to find it and `heal` to fix it. `diagnose` checks bottom-up — containers,
addresses, forwarding, BGP sessions, prefixes, data path — and stops at the
lowest failing layer.

Useful manual commands include:

```bash
docker exec -it clab-bgp-lab-r1 vtysh -c 'show bgp summary'
docker exec -it clab-bgp-lab-r1 vtysh -c 'show bgp ipv4 unicast'
docker exec -it clab-bgp-lab-r1 vtysh -c 'show bgp ipv4 unicast 10.3.0.0/16'
docker exec -it clab-bgp-lab-r1 ip route
```

### Understanding `State/PfxRcd`

In `show bgp summary`, the final `State/PfxRcd` column has two meanings. A word such as `Idle`, `Active`, or `Connect` means that the session is not established and shows its current BGP finite-state-machine state. A number means the session is `Established`; the number is the count of prefixes received from that neighbor. A value of `0` can therefore still describe a healthy established session that has received no prefixes.

### R1's best path to R5

R1 learns 10.3.0.0/16 through two paths:

```text
via r2: 200 300
via r3: 400 300
```

Both paths have the same default Local Preference and the same AS-path length. With the other important attributes also tied, FRR proceeds through later best-path tie breakers. The lab enables `bgp bestpath compare-routerid` to make this result deterministic instead of preferring the oldest external path. The path learned from R2 therefore wins because its peer router ID, 2.2.2.2, is lower than R3's 3.3.3.3. Do not treat the AS numbers themselves as a preference: BGP compares AS-path length, not the numeric magnitude of each ASN.

Apply the focused Local Preference policy and inspect the result:

```bash
./lab.sh prefer-r3
```

The inbound route map assigns Local Preference 200 only to 10.3.0.0/16 received from R3. A second permit clause passes all other R3 routes unchanged. R1 then selects `400 300` for that prefix despite the otherwise tied paths. Restore the baseline with:

```bash
./lab.sh reset-policy
```

## Why `dummy0` is used instead of `lo`

Each advertised internal AS network is installed on a dedicated Linux `dummy0` interface. Transit addressing remains exclusively on `eth1`, `eth2`, and `eth3`. This gives every simulated customer/internal prefix a real connected route while keeping its role separate from router-local and transit addressing.

The specific mistake this design avoids is assigning a large network such as 10.3.0.1/16 directly to Linux `lo`, then being surprised when connected-route semantics, interface behavior, or BGP propagation do not match the intended lab model. Linux loopback is special and is best reserved for host-local addresses. A dummy interface behaves like a regular always-up Layer 3 interface without requiring a physical peer, which makes the lab stable and the routing intent explicit.

FRR's BGP `network 10.3.0.0/16` statement does not create that route. With BGP network import checking enabled, it originates the prefix only if an exact 10.3.0.0/16 route already exists in the local routing table. Assigning 10.3.0.1/16 to `dummy0` creates exactly that connected route before the BGP configuration is applied.

## Control plane and data plane

The control plane is where FRR establishes BGP sessions, exchanges Network Layer Reachability Information, evaluates attributes, and selects best paths. Commands such as `show bgp summary` and `show bgp ipv4 unicast` inspect this plane.

The data plane is the Linux kernel forwarding traffic according to installed routes. Commands such as `ip route` and the end-to-end ping tests inspect it. A prefix visible in the BGP table proves control-plane learning; a successful sourced ping additionally proves that selected routes were installed and forwarding works in both directions.

## Troubleshooting

1. Confirm Docker and the containers: `docker ps --filter name=clab-bgp-lab`.
2. Confirm interface addresses: `docker exec clab-bgp-lab-r1 ip addr`.
3. Confirm the local dummy route: `docker exec clab-bgp-lab-r1 ip route get 10.1.0.1`.
4. Check peer states and received prefix counts: `./lab.sh routes`.
5. Check the kernel's BGP routes: `docker exec clab-bgp-lab-r1 vtysh -c 'show ip route bgp'`.
6. Reapply the idempotent configuration with `./lab.sh configure` if a container was restarted.
7. Run `./lab.sh verify`; on any failure it automatically prints BGP summaries, the BGP table, FRR BGP routes, Linux routes, and interface addresses for every available router.

If peers remain `Active`, verify both ends of the /30 link and their `remote-as` values. If a `network` prefix is absent, first verify that the exact /16 connected route exists through `dummy0`. If BGP learns a route but ping fails, inspect `show ip route bgp`, Linux `ip route`, IP forwarding, and the reverse path.
