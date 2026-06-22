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

Each lab ships an interactive `lab.sh` menu. The top-level `lab.sh` in this
directory is a launcher: run it without arguments to open any lab's menu or to
run a single action directly. The scripts run as the invoking user and escalate
to `sudo` only where Containerlab or host networking actually require root.

```bash
./lab.sh                 # interactive launcher (pick a lab or an action)
./lab.sh bgp             # open the bgp-lab menu
./lab.sh nat4 deploy     # run a single action in a lab
```

Two global actions are not tied to a single lab:

```bash
./lab.sh doctor          # check docker, containerlab and sudo are available
./lab.sh lint            # lint every shell script (bash -n + shellcheck)
```

A typical lab is deployed, verified, and torn down like this:

```bash
cd <lab-directory>
./lab.sh deploy
./lab.sh verify
./lab.sh state           # quick per-node status
./lab.sh inspect         # containerlab view plus per-node state
# ... experiment, break things, inspect logs ...
./lab.sh destroy
```

Every lab exposes `deploy`, `verify`, `state`, `inspect` and `destroy`; run a
lab's `./lab.sh` without an action to see its full menu. See the README inside
each lab for the specific actions and scenarios.

### Break things on purpose

The real learning is diagnosing a broken lab. Each lab can inject realistic,
reversible faults and restore itself:

```bash
./lab.sh bgp break       # pick a named fault, or a random "mystery" one
./lab.sh bgp diagnose    # guided, layer-by-layer diagnosis with hints
./lab.sh bgp verify      # flat pass/fail suite (also: state, inspect)
./lab.sh bgp heal        # restore the known-good baseline (reveals a mystery)
./lab.sh bgp config      # show the running config and optionally edit + re-apply
```

A mystery fault is not revealed until you `heal`, so you can practise pure
diagnosis. `diagnose` walks the network bottom-up and stops at the lowest
failing layer with a hint — pointing at the problem area without naming the
fault. `config` lets you view the effective configuration and tweak the source
to experiment.

## License

See [LICENSE](./LICENSE).
