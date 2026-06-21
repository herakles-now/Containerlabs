# Overall Topology and Address Plan

Each line between an endpoint and a gateway represents a dedicated bridge segment. No scenario shares a data path with another scenario.

```text
Static NAT
static-host --- br-n4-si --- static-gw --- br-n4-so --- static-server
10.10.1.10                 .1 |   | .1                   198.51.100.100
                    public mapping: 198.51.100.10

Dynamic NAT
dynamic-host1 --+
10.10.2.10       |
                 +-- br-n4-di -- dynamic-gw -- br-n4-do -- dynamic-server
dynamic-host2 --+                .1 |   | .1               198.51.101.100
10.10.2.11              pool: 198.51.101.10-20

Port Forwarding
forward-server -- br-n4-fi -- forward-gw -- br-n4-fo -- forward-client
10.10.3.10:80             .1 |   | .1                    198.51.102.100
                              public :8080

PAT
pat-host1 --+
10.10.4.10   |
             +-- br-n4-pi -- pat-gw -- br-n4-po -- pat-server
pat-host2 --+               .1 |   | .1              198.51.103.100
10.10.4.11                    shared public IP
```

| Case | Inside | Gateway inside | Gateway outside | Public mapping/pool | Remote endpoint |
|---|---|---|---|---|---|
| Static | 10.10.1.10/24 | 10.10.1.1 | 198.51.100.1 | 198.51.100.10 | 198.51.100.100 |
| Dynamic | 10.10.2.10, .11/24 | 10.10.2.1 | 198.51.101.1 | 198.51.101.10-.20 | 198.51.101.100 |
| Forward | 10.10.3.10/24 | 10.10.3.1 | 198.51.102.1 | 198.51.102.1:8080 | 198.51.102.100 |
| PAT | 10.10.4.10, .11/24 | 10.10.4.1 | 198.51.103.1 | 198.51.103.1 | 198.51.103.100 |

Every gateway uses `eth1 = inside` and `eth2 = outside`. Management interface `eth0` belongs exclusively to the Containerlab management network 172.30.0.0/24.
