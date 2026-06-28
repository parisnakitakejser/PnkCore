# Cilium Architecture Student Labs

This domain contains hands-on Cilium architecture labs for local Kind clusters. The modules are numbered so students can start with the datapath foundation and then move into policy, observability, Gateway API, service mesh, egress, and Cluster Mesh.

The goal is not only to run commands. Each lab is written to help students connect three layers:

- Kubernetes intent: objects such as Pods, Services, NetworkPolicies, Gateways, and Routes.
- Cilium control plane: agents, operator, CRDs, identities, Envoy configuration, and Cluster Mesh state.
- Linux datapath: eBPF programs, eBPF maps, routing, tunneling, policy decisions, and packet forwarding.

When reading an architecture lab, use this pattern:

1. Read the diagram first and identify where traffic starts and ends.
2. Find the Kubernetes object that expresses the desired behavior.
3. Identify which Cilium component watches that object.
4. Identify where the actual packet decision happens: eBPF, Envoy, DNS proxy, or Cluster Mesh.
5. Run the verification command and connect its output back to the diagram.

Each guide includes:

- What architecture pattern the lab demonstrates
- Step-by-step commands
- Verification checks
- Cleanup commands
- Notes about what else can exist in real deployments

## How to Study These Labs

Treat every module as a small architecture investigation. Before applying a manifest, open it and ask what problem it is trying to solve. After applying it, inspect both Kubernetes state and Cilium state. This is important because Cilium architecture is split across Kubernetes resources, Cilium controllers, and kernel-level datapath state.

For example, a Kubernetes `Service` tells the cluster that clients should use a stable virtual address. Cilium then converts that desired state into eBPF load-balancing entries. A `CiliumNetworkPolicy` tells the cluster which identities may talk. Cilium then turns label selectors into numeric identities and policy map entries. A Gateway API `HTTPRoute` tells the cluster how to match HTTP requests. Cilium then programs Envoy so that HTTP-level routing can happen before traffic reaches the backend Service.

Students should focus on these repeated questions:

- What object did I create?
- Which component reacts to it?
- Where is the decision enforced?
- What command proves that the architecture is working?
- What would change in a production cluster compared with Kind?

## Suggested Learning Path

Start with module `00` even if you already know Kind. The later modules assume that you understand the difference between the Kubernetes control plane, the Cilium control plane, and the datapath on each node.

Modules `01`, `02`, and `03` build the core mental model: service translation, identity-based policy, and routing. Modules `04`, `05`, `06`, and `07` add operational and L7 features. Module `08` expands the same ideas across multiple clusters.

Do not skip cleanup. Several modules reuse the same cluster name, host ports, and Gateway API resources. Cleaning up keeps each lab independent and makes troubleshooting easier.

## Prerequisites

Install these tools before starting:

- Docker or another Kind-compatible container runtime
- `kind`
- `kubectl`
- `cilium`
- `hubble`
- `curl`
- `jq`
- `helm` for optional chart inspection

## Module Order

1. `00-kind-cilium-foundation` - baseline Kind cluster with Cilium.
2. `01-ebpf-datapath-and-kube-proxy-replacement` - service load balancing without kube-proxy.
3. `02-identity-and-network-policy-architecture` - Cilium identity and L3/L4/L7 policy.
4. `03-routing-architectures-overlay-vs-native` - overlay versus native routing architecture.
5. `04-observability-with-hubble` - flow visibility and troubleshooting.
6. `05-gateway-api-north-south-architecture` - Cilium Gateway API ingress architecture.
7. `06-gamma-service-mesh-east-west-architecture` - sidecarless east-west L7 routing.
8. `07-egress-and-l7-proxy-architecture` - egress DNS and HTTP-aware policy.
9. `08-cluster-mesh-architecture-on-kind` - two Kind clusters joined by Cilium Cluster Mesh.

## Local Testing Convention

Most modules use a cluster named `cilium-arch`:

```bash
kind create cluster --name cilium-arch --config kind-config.yaml
```

If a module needs a different cluster shape, it provides its own commands. Always run cleanup before moving to a module that creates clusters with the same names.

## Reading Command Output

The commands in these labs are chosen to answer architecture questions, not only to prove that something is running.

- `kubectl get` shows Kubernetes desired and observed state.
- `kubectl describe` shows conditions, controller feedback, and attachment errors.
- `cilium status` shows whether Cilium components agree that the datapath is healthy.
- `cilium service list`, `cilium endpoint list`, and `cilium identity list` show Cilium's internal view of Kubernetes objects.
- `hubble observe` shows what actually happened to traffic after Cilium made a datapath decision.

If a command fails, read the error as architecture feedback. A missing CRD usually means the API type was not installed. A route with `Accepted=False` usually means a Gateway API attachment rule rejected it. A policy timeout often means traffic was dropped before the application could respond.
