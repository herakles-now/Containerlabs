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

## Inspiration

These labs are inspired by the training courses created by
[Adrian Cantrill](https://learn.cantrill.io/), including his free Tech
Fundamentals course. They are independent, hands-on implementations built to
reinforce and extend the networking and infrastructure concepts covered in
those courses. This repository is not officially affiliated with or endorsed by
Adrian Cantrill.

After 26 years in IT, I can strongly recommend Adrian's courses. Revisiting
familiar topics through his training helped me understand many of them more
clearly and at a greater depth. Most IT professionals know the OSI model, but
Adrian's explanations helped me refresh that knowledge and develop a deeper,
more practical understanding that continues to improve how I reason about and
troubleshoot real systems.

## Requirements

- [Containerlab](https://containerlab.dev/install/)
- A container runtime (Docker / Podman)
- Linux host (or VM) with sufficient privileges to create network namespaces

## Labs

| Lab | Description |
| --- | --- |
| [`ipsec-lab`](./ipsec-lab) | strongSwan-based IPsec site-to-site VPN lab. |
| [`bgp-lab`](./bgp-lab) | Seven-AS FRRouting eBGP lab covering route propagation, best-path selection, multihoming, and Local Preference. |
| [`nat4-lab`](./nat4-lab) | Four isolated nftables NAT scenarios with packet captures and conntrack inspection. |

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
