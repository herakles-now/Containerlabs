# IPsec / strongSwan Lab with Containerlab

## Goal

This lab demonstrates a route-based traffic path with a policy-based
IPsec tunnel in tunnel mode. PC1 and PC2 send normal IPv4/ICMP. R1 and R2
select the traffic based on the traffic selectors, encrypt it with ESP
and apply the kernel-managed XFRM policies and states.

The transit container simulates the Internet. It deliberately has no routes to
the two LAN networks. On it you can observe:

- IKEv2 negotiates the SAs over UDP/500.
- NAT-T over UDP/4500 would be possible, but is not needed in this lab without NAT.
- Payload traffic then runs as ESP (IP protocol 50) between the WAN addresses.
- The inner addresses `10.1.0.10` and `10.2.0.10` are not visible on the transit.
- ESP SAs are unidirectional. One SA each for R1 → R2 and R2 → R1 forms the
  SA pair for bidirectional traffic.

## Topology

```text
       10.1.0.0/24          100.64.1.0/30       100.64.2.0/30         10.2.0.0/24

 PC1 ---------------- R1 ---------------- Transit ---------------- R2 ---------------- PC2
 .10       eth1  .1   .1 eth2         eth1 .2  .1 eth2         eth1 .2   .1 eth2       .10
                    strongSwan             Logger                   strongSwan

                         <======= IKEv2 / ESP Tunnel =======>
                              100.64.1.1 ↔ 100.64.2.2
                         Traffic Selectors: 10.1/24 ↔ 10.2/24
```

## IP plan

| Node | Interface | Address | Purpose |
|---|---|---:|---|
| PC1 | eth1 | 10.1.0.10/24 | left LAN |
| R1 | eth1 | 10.1.0.1/24 | left LAN gateway |
| R1 | eth2 | 100.64.1.1/30 | left WAN IP / IKE ID |
| Transit | eth1 | 100.64.1.2/30 | transit left |
| Transit | eth2 | 100.64.2.1/30 | transit right |
| R2 | eth1 | 100.64.2.2/30 | right WAN IP / IKE ID |
| R2 | eth2 | 10.2.0.1/24 | right LAN gateway |
| PC2 | eth1 | 10.2.0.10/24 | right LAN |

R1 uses `100.64.1.2` and R2 uses `100.64.2.1` as the default gateway. PC1 and PC2
each use their local router. The transit only has its two directly connected
`/30` networks. Containerlab's separate management network uses
`172.31.250.0/24` and is not part of the data path shown here.

## Prerequisites

- Linux host with kernel XFRM support
- Docker
- Containerlab
- `sudo` privileges for Containerlab

## Build and deploy

From this directory:

```bash
docker build -t ipsec-alpine:latest .
sudo containerlab deploy -t ipsec-lab.clab.yml
```

Packaging note: Alpine 3.20 ships `/usr/sbin/swanctl` as part of the
`strongswan` package; unlike some distributions, Alpine does not provide a
separate `strongswan-swanctl` package. The Docker build therefore explicitly
verifies that `swanctl` is present.

The startup scripts configure the data interfaces, forwarding and `rp_filter`.
On R1 and R2, strongSwan is started and the respective `swanctl.conf` is loaded.
`start_action = trap` first installs XFRM trap policies; matching traffic
from PC1 triggers the IKE negotiation and subsequently the CHILD_SA.
MOBIKE is explicitly disabled so that strongSwan does not preemptively switch
from UDP/500 to UDP/4500 without NAT, keeping the capture unambiguous for this learning goal.

## Tests

### 1. WAN reachability

These pings run outside the LAN traffic selectors and are therefore unencrypted:

```bash
docker exec -it clab-ipsec-lab-r1 ping -c 3 100.64.2.2
docker exec -it clab-ipsec-lab-r2 ping -c 3 100.64.1.1
```

### 2. Trigger the tunnel

```bash
docker exec -it clab-ipsec-lab-pc1 ping -c 5 10.2.0.10
```

The first ping may be lost during the IKE negotiation. After that, replies
should arrive.

### 3. View from the transit container

```bash
docker exec -it clab-ipsec-lab-transit tail -f /var/log/ipsec-lab/transit.log
```

During tunnel setup, UDP/500 between `100.64.1.1` and `100.64.2.2` is visible.
Afterwards the ping appears as ESP between these WAN IPs. A capture on the
transit must not show any ICMP packets with `10.1.0.10 → 10.2.0.10` or the
reverse direction for the protected ping. UDP/4500 only appears when NAT is
detected and NAT-T is enabled; that is not the case here.

### 4. IKE and CHILD_SAs

```bash
docker exec -it clab-ipsec-lab-r1 swanctl --list-sas
docker exec -it clab-ipsec-lab-r2 swanctl --list-sas
```

The output shows the IKE_SA as well as the CHILD_SA with the negotiated traffic
selectors `10.1.0.0/24` and `10.2.0.0/24`.

### 5. XFRM policies

```bash
docker exec -it clab-ipsec-lab-r1 ip xfrm policy
docker exec -it clab-ipsec-lab-r2 ip xfrm policy
```

Policies decide, based on source, destination and direction (`in`, `out`, `fwd`),
which layer 3 traffic must be protected. Before setup, the outgoing policy is a
trap policy; after the negotiation it points to the tunnel.

### 6. XFRM states and unidirectional SAs

```bash
docker exec -it clab-ipsec-lab-r1 ip xfrm state
docker exec -it clab-ipsec-lab-r2 ip xfrm state
```

An XFRM state describes exactly one direction and has, among other things, its
own SPI. That is why two ESP SAs are needed:

```text
R1 (100.64.1.1)  -- ESP SA / own SPI -->  R2 (100.64.2.2)
R1 (100.64.1.1)  <-- ESP SA / other SPI --  R2 (100.64.2.2)
```

Only this SA pair enables bidirectional communication. This illustrates
that the SA itself is unidirectional, even though one colloquially speaks of
"the tunnel".

## Additional diagnostics

```bash
docker exec -it clab-ipsec-lab-r1 swanctl --list-conns
docker exec -it clab-ipsec-lab-r2 swanctl --list-conns
docker exec -it clab-ipsec-lab-transit ip route
docker logs clab-ipsec-lab-r1
docker logs clab-ipsec-lab-r2
```

## Tear down the lab

```bash
sudo containerlab destroy -t ipsec-lab.clab.yml
sudo containerlab destroy -t ipsec-lab.clab.yml --cleanup
```

The second command additionally removes the lab files generated by Containerlab.
