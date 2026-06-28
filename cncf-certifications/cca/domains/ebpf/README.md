# eBPF Study Labs For Cilium

This domain teaches the Cilium eBPF concepts needed for CCA study. You are not expected to write eBPF programs. You are expected to understand how Cilium uses eBPF programs, maps, identities, routing, policy, observability, and encryption to implement Kubernetes networking.

Use the modules in order. Modules `01` through `06` are runnable labs with manifests. The other modules are architecture and troubleshooting study notes.

## Core Exam Model

Keep this flow in mind for every topic:

```text
Kubernetes intent -> Cilium agent -> eBPF maps/programs -> packet behavior -> Hubble or cilium-dbg evidence
```

When troubleshooting, ask:

1. Does Kubernetes have the expected object state?
2. Did Cilium learn and program that state?
3. Which eBPF map, identity, policy, route, or feature controls the packet?
4. What does Hubble show for real traffic?

## Modules

| Module | What It Teaches |
| --- | --- |
| [00 - eBPF Foundations](00-ebpf-foundations/README.md) | Explains eBPF programs, hooks, maps, verifier, tail calls, XDP, and the control-plane/datapath split. Start here to understand the vocabulary used by all later labs. |
| [01 - Cilium eBPF Datapath](01-cilium-ebpf-datapath/README.md) | Builds a Cilium cluster and shows how pods become Cilium endpoints. Focus on proving that Cilium knows about workloads, not only that Kubernetes pods are running. |
| [02 - eBPF Maps And Identities](02-ebpf-maps-and-identities/README.md) | Shows how labels become Cilium security identities and how eBPF maps hold runtime datapath state. This is the base for policy, services, CT/NAT, and troubleshooting. |
| [03 - Kube-Proxy Replacement](03-kube-proxy-replacement/README.md) | Explains how Cilium handles Kubernetes Service translation in eBPF instead of kube-proxy iptables/IPVS rules. Focus on Service frontend, endpoints, and Cilium service state. |
| [04 - Service Load Balancing With eBPF](04-service-load-balancing-with-ebpf/README.md) | Explains how ClusterIP traffic is translated to backend pods and why connection state matters after a backend is selected. Useful for Service and backend troubleshooting. |
| [05 - Network Policy Enforcement With eBPF](05-network-policy-enforcement-with-ebpf/README.md) | Connects CiliumNetworkPolicy, labels, identities, endpoint policy state, and Hubble verdicts. Focus on which endpoint is selected and which identity is allowed. |
| [06 - Hubble Flow Visibility](06-hubble-flow-visibility/README.md) | Shows how to observe real datapath flows, verdicts, protocols, and drops. Use this to prove what happened to traffic after checking config and Cilium state. |
| [07 - Transparent Encryption With IPsec And WireGuard](07-transparent-encryption-ipsec-and-wireguard/README.md) | Compares Cilium transparent encryption modes. Learn the difference between IPsec Secret-based keys and WireGuard peer/key handling through Cilium node state. |
| [08 - eBPF Troubleshooting](08-ebpf-troubleshooting/README.md) | Gives a repeatable troubleshooting workflow: Cilium health, Kubernetes objects, endpoints, services, identities, policy, Hubble, routing, and encryption. |
| [09 - Tail Calls And XDP](09-tail-calls-and-xdp/README.md) | Explains how tail calls split large eBPF datapaths and how XDP provides very early packet handling. Keep this at architecture level for the exam. |
| [10 - Connection Tracking And NAT](10-connection-tracking-and-nat/README.md) | Explains CT and NAT maps, first-packet versus established-packet behavior, reply translation, and why existing connections can behave differently from new ones. |
| [11 - Host Routing And Native Routing](11-host-routing-and-native-routing/README.md) | Separates Service translation from packet delivery. Covers tunnel mode, native routing, pod CIDR reachability, same-node versus cross-node traffic, and routing failures. |
| [12 - eBPF Map Pressure And Sizing](12-bpf-map-pressure-and-sizing/README.md) | Covers finite map capacity, pressure symptoms, and why large clusters or high connection churn can affect CT, NAT, service, policy, and endpoint maps. |
| [13 - Datapath Modes And Feature Flags](13-datapath-modes-and-feature-flags/README.md) | Explains how Cilium install values change behavior: kube-proxy replacement, routing mode, Hubble, encryption, host firewall, L7 policy, and other datapath features. |

## Tooling

Runnable labs use Podman-backed Kind clusters:

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name <name> --config kind-config.yaml
```

Common tools:

```bash
kubectl
kind
helm
cilium
hubble
podman
```

## Commands To Remember

```bash
cilium status
cilium config view
kubectl -n kube-system exec ds/cilium -- cilium-dbg endpoint list
kubectl -n kube-system exec ds/cilium -- cilium-dbg identity list
kubectl -n kube-system exec ds/cilium -- cilium-dbg service list
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf map list
hubble status -P
hubble observe -P
hubble observe -P --verdict DROPPED
```

## Study Method

For each module, learn the concept, run the lab when provided, then explain what changed in the datapath. The exam skill is knowing which layer to inspect: Kubernetes object, Cilium endpoint, identity, service map, CT/NAT state, policy, route, encryption state, or Hubble flow.
