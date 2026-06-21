# Dynamic Port NAT / PAT

```text
10.10.4.10:43000 --+
                    +-- [ pat-gw 198.51.103.1 ] --> 198.51.103.100:80
10.10.4.11:43000 --+
```

## Address Plan

- Inside hosts: 10.10.4.10/24 and 10.10.4.11/24
- Gateway inside/outside: 10.10.4.1/24 and 198.51.103.1/24
- Outside server: 198.51.103.100/24

## nftables Rules

```nft
oifname "eth2" ip saddr 10.10.4.0/24 masquerade
```

## Expected tcpdump Output

```text
[INSIDE]  10.10.4.10.43000 > 198.51.103.100.80
[INSIDE]  10.10.4.11.43000 > 198.51.103.100.80
[OUTSIDE] 198.51.103.1.43000 > 198.51.103.100.80
[OUTSIDE] 198.51.103.1.43001 > 198.51.103.100.80
```

The exact translated port is implementation-dependent.

## Expected Conntrack Output

Two entries contain different private original sources but the same public address in the reply tuple. Their public ports differ. Before NAT, Layer 3 distinguishes the hosts; after NAT, Layer 4 must distinguish the flows. PAT therefore changes the source address and, for this intentionally created collision, at least one source port.
