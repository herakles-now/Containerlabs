# ContainerLab Labs

A collection of hands-on [Containerlab](https://containerlab.dev/) labs built to
develop a deeper, practical understanding of **network and cloud
infrastructure**.

## Goal

The aim of this repository is to grow a set of meaningful labs that go beyond
"happy path" tutorials. The focus is **learning by breaking things**:

- **Build realistic topologies** — routers, gateways, VPN tunnels, services and
  the connections between them.
- **Deliberately introduce faults** — misconfigure a route, drop an MTU, break a
  pre-shared key, partition a network — and observe *how* and *where* the failure
  manifests.
- **Trace cause and effect** — follow the impact from the point of failure
  through the stack to the symptom a user or service would actually see.
- **Learn the right logs** — figure out which logs, counters and diagnostic
  commands get you to the root cause *fast*, so troubleshooting becomes a skill
  rather than guesswork.

In short: a safe sandbox to make mistakes on purpose, watch what happens, and
build the instincts and observability know-how needed to debug real
infrastructure quickly.

## Requirements

- [Containerlab](https://containerlab.dev/install/)
- A container runtime (Docker / Podman)
- Linux host (or VM) with sufficient privileges to create network namespaces

## Labs

| Lab | Description |
| --- | --- |
| [`ipsec-containerlab`](./ipsec-containerlab) | strongSwan-based IPsec site-to-site VPN lab. |
| [`bgp-lab`](./bgp-lab) | Seven-AS FRRouting eBGP lab covering route propagation, best-path selection, multihoming, and Local Preference. |
| [`nat4-containerlab`](./nat4-containerlab) | Four isolated nftables NAT scenarios with packet captures and conntrack inspection. |

Each lab lives in its own directory with a dedicated `README.md` describing the
topology, how to deploy it, and the failure scenarios to experiment with.

## Usage

A typical lab is deployed, verified, and torn down like this:

```bash
cd <lab-directory>
sudo make deploy
sudo make verify
# ... experiment, break things, inspect logs ...
sudo make destroy
```

See the README inside each lab for the specific commands and scenarios.

## License

See [LICENSE](./LICENSE).
