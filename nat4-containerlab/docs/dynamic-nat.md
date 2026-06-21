# Dynamic NAT from an Address Pool

```text
10.10.2.10:42000 --+
                    +-- eth1 [ dynamic-gw ] eth2 -- 198.51.101.100:80
10.10.2.11:42000 --+             |
                         198.51.101.10-.20
```

## Address Plan

- Inside hosts: 10.10.2.10/24 and 10.10.2.11/24
- NAT inside/outside: 10.10.2.1/24 and 198.51.101.1/24
- Pool: 198.51.101.10 through 198.51.101.20
- Outside server: 198.51.101.100/24

## nftables Rules

```nft
oifname "eth2" ip saddr 10.10.2.0/24 snat to 198.51.101.10-198.51.101.20
```

## Expected tcpdump Output

```text
[INSIDE]  10.10.2.10.42000 > 198.51.101.100.80
[INSIDE]  10.10.2.11.42000 > 198.51.101.100.80
[OUTSIDE] 198.51.101.10.42000 > 198.51.101.100.80
[OUTSIDE] 198.51.101.11.42000 > 198.51.101.100.80
```

The exact selected pool addresses can differ. The important result is two distinct addresses from `.10-.20`.

## Expected Conntrack Output

Two entries contain the two private original sources and two public reply destinations. Before NAT, the inside addresses distinguish the flows; after NAT, the flows originate from the public pool. Layer 3 is the primary layer being changed. Ports are not intentionally translated, although conntrack may change one if an otherwise unresolvable tuple collision occurs.
