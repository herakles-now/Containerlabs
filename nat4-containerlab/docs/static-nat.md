# Static NAT

```text
10.10.1.10:41000 -- eth1 [ static-gw ] eth2 -- 198.51.100.100:80
                               |
                         198.51.100.10
```

## Address Plan

- Inside host: 10.10.1.10/24, gateway 10.10.1.1
- NAT inside: 10.10.1.1/24
- NAT outside: 198.51.100.1/24 and mapping address 198.51.100.10/32
- Outside server: 198.51.100.100/24

## nftables Rules

```nft
iifname "eth2" ip daddr 198.51.100.10 dnat to 10.10.1.10
oifname "eth2" ip saddr 10.10.1.10 snat to 198.51.100.10
```

## Expected tcpdump Output

```text
[INSIDE]  10.10.1.10.41000 > 198.51.100.100.80
[OUTSIDE] 198.51.100.10.41000 > 198.51.100.100.80
```

## Expected Conntrack Output

```text
tcp ... src=10.10.1.10 dst=198.51.100.100 sport=41000 dport=80 ...
        src=198.51.100.100 dst=198.51.100.10 sport=80 dport=41000
```

Before NAT, the private source address is visible. After NAT, the fixed public address replaces it. The source port is preserved: OSI Layer 3 changes, while Layer 4 is not intentionally changed. The DNAT rule also supports the conceptual inbound direction toward the fixed mapping address; reply packets for established flows use conntrack state.
