# Static Port NAT / Port Forwarding

```text
198.51.102.100:any --> 198.51.102.1:8080 [ forward-gw ] --> 10.10.3.10:80
       outside                  eth2        eth1              inside
```

## Address Plan

- Outside client: 198.51.102.100/24
- Gateway outside/inside: 198.51.102.1/24 and 10.10.3.1/24
- Inside server: 10.10.3.10/24, HTTP on port 80
- Public destination: 198.51.102.1:8080

## nftables Rules

```nft
iifname "eth2" ip daddr 198.51.102.1 tcp dport 8080 dnat to 10.10.3.10:80
```

## Expected tcpdump Output

```text
[OUTSIDE] 198.51.102.100.50000 > 198.51.102.1.8080
[INSIDE]  198.51.102.100.50000 > 10.10.3.10.80
```

## Expected Conntrack Output

```text
tcp ... src=198.51.102.100 dst=198.51.102.1 sport=50000 dport=8080 ...
        src=10.10.3.10 dst=198.51.102.100 sport=80 dport=50000
```

Before NAT, the public gateway destination is visible. After NAT, the internal destination address and port 80 are visible. Both Layer 3 and Layer 4 therefore change. The server replies through its default route to the gateway, and conntrack performs the inverse translation on the return path.
