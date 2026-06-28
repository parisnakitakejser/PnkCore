# BGP And External Networking With Cilium

This module teaches how Cilium can make Kubernetes `LoadBalancer` Services
reachable from an external network by advertising service IPs with BGP.

The labs are written as a student learning path. Each section builds on the
previous one, starting with the networking concepts and ending with an
end-to-end external client test and troubleshooting flow.

## What You Will Learn

By the end of this module, you should understand:

- Why a Kubernetes `LoadBalancer` Service needs both an IP address and a route
  in the external network.
- What problem Cilium BGP Control Plane solves on local, lab, and bare-metal
  clusters.
- How a Kind cluster, a Cilium installation, and an FRR router fit together in
  a small BGP lab.
- How Cilium peers with an external router by using BGP.
- How Cilium allocates `LoadBalancer` IPs from a pool and advertises those IPs
  to a BGP peer.
- How to test access from a client outside the Kubernetes cluster.
- How to troubleshoot the difference between BGP control-plane problems and
  service data-plane problems.

## Mental Model

The main idea for this module is:

```text
Kubernetes creates the Service.
Cilium assigns a LoadBalancer IP.
Cilium advertises that IP with BGP.
FRR learns the route.
An external client sends traffic through the routed network.
Cilium forwards the traffic to the Service backend.
```

BGP does not carry HTTP traffic and does not create Kubernetes Services. BGP
only teaches the external router where a service IP is reachable. After the
router learns the route, normal IP forwarding carries the application traffic.

## Lab Environment

These labs use Podman, Kind, Cilium, and FRR:

- Podman provides the local container network used by the lab.
- Kind provides a local Kubernetes cluster running on Podman containers.
- Cilium is installed as the cluster CNI and enables BGP Control Plane.
- FRR acts as the external router that learns routes from Cilium.
- A temporary external client container is used to test access from outside the
  Kubernetes cluster.

Use Podman for this module. The topology lab uses `compose.yaml` and
`podman compose`.

## Shared Topology

`01-kind-podman-frr-cilium-setup/` is the central lab setup for this whole
module. It is intentionally not copied into `02-*` through `05-*`.

Later sections reuse the same running Kind cluster, Podman network, FRR router,
and Cilium installation from `01-*`:

- `02-*` adds Cilium BGP peering to the shared FRR router.
- `03-*` adds service IP pools, a test service, and BGP advertisements.
- `04-*` tests the resulting external path from a temporary client.
- `05-*` troubleshoots the same shared environment.

If a later lab has no topology files, that is expected. Only create additional
topology files in a later lab if that lab intentionally uses a different
network, router, cluster, or failure scenario.

## Learning Path

Work through the sections in order. Later labs assume the resources from
earlier labs already exist.

### [00 - External Networking And BGP Foundations](00-external-networking-and-bgp-foundations/)

Folder: [`00-external-networking-and-bgp-foundations/`](00-external-networking-and-bgp-foundations/)

This section explains the problem before you start applying configuration. It
covers Kubernetes Service types, why `ClusterIP` is internal, what a
`LoadBalancer` Service adds, and why bare-metal or local clusters need a way to
make service IPs reachable from outside the cluster.

It also introduces the BGP concepts used in the rest of the module. The goal is
not to become a full network engineer. The goal is to understand that BGP
advertises routes, ARP works only on a local Layer 2 network, and an external
router must learn where the Kubernetes service IP lives.

Read this section first if you are unsure why assigning a service IP is not the
same as making that IP reachable.

### [01 - Kind Podman FRR And Cilium Setup](01-kind-podman-frr-cilium-setup/)

Folder: [`01-kind-podman-frr-cilium-setup/`](01-kind-podman-frr-cilium-setup/)

This section builds the shared local lab environment. You create the `bgp-kind`
Podman network, create a Kind cluster on that network, start an FRR router
container at `172.18.0.254`, then install Cilium as the cluster CNI with BGP
Control Plane enabled.

The important point is that this lab prepares the environment, not the BGP
session. At the end of this section, FRR is running and Cilium can speak BGP,
but no Cilium BGP peer resources exist yet. Seeing no established BGP peers is
expected.

Key files:

- `kind-config.yaml` defines the Kind cluster.
- `compose.yaml` starts the FRR router container.
- `frr/frr.conf` configures FRR with ASN `65000` and a dynamic peer range.

### [02 - BGP Peering With FRR](02-bgp-peering-with-frr/)

Folder: [`02-bgp-peering-with-frr/`](02-bgp-peering-with-frr/)

This section creates the BGP neighbor relationship between Cilium and the FRR
router.

You apply Cilium BGP custom resources that tell Cilium to use ASN `65001` and
peer with FRR at `172.18.0.254`, where FRR uses ASN `65000`. This creates an
eBGP session between the Kubernetes side and the external router side.

The main resources are:

- `CiliumBGPPeerConfig`, which defines reusable peer settings such as timers
  and advertisement label selection.
- `CiliumBGPClusterConfig`, which defines the local Cilium ASN, the remote FRR
  ASN, the peer address, and which nodes receive the BGP configuration.

The goal of this section is to see the BGP session reach `Established`. That
proves Cilium and FRR can reach each other and agree on the BGP configuration.
It does not mean a service IP has been advertised yet.

### [03 - LoadBalancer IP Pools And Advertisements](03-loadbalancer-ip-pools-and-advertisements/)

Folder: [`03-loadbalancer-ip-pools-and-advertisements/`](03-loadbalancer-ip-pools-and-advertisements/)

This section connects two ideas that are easy to mix up: assigning a
`LoadBalancer` IP and advertising that IP to the external router.

First, you create a `CiliumLoadBalancerIPPool` that allows Cilium to assign
service IPs from `172.19.100.10` through `172.19.100.250`. Then you deploy an
nginx workload and a Kubernetes `LoadBalancer` Service. Cilium assigns an
external IP from the pool to that Service.

After the Service has an IP, you create a `CiliumBGPAdvertisement`. This tells
Cilium to advertise matching `LoadBalancer` service IPs over the already
established BGP session.

The key lesson is:

- The IP pool answers: "which IPs may Services use?"
- The BGP advertisement answers: "which Service IPs should be exported to BGP?"

At the end of this section, FRR should learn a `/32` route for the nginx
Service's `LoadBalancer` IP.

### [04 - External Client Testing](04-external-client-testing/)

Folder: [`04-external-client-testing/`](04-external-client-testing/)

This section tests the complete external access path. You get the
`LoadBalancer` IP from the nginx Service, confirm that the backend pod and
service endpoints exist, confirm that FRR learned the route, and then send an
HTTP request from a temporary client container outside the Kubernetes cluster.

This is the first section where the full data path is tested:

```text
external client -> FRR -> Kubernetes node -> Cilium service handling -> nginx
```

The test is intentionally run from outside Kubernetes. Curling from a pod only
proves cluster-internal networking. Curling from an external client proves that
the BGP-advertised service IP can be reached from the routed network.

### [05 - BGP Troubleshooting](05-bgp-troubleshooting/)

Folder: [`05-bgp-troubleshooting/`](05-bgp-troubleshooting/)

This section gives you a practical troubleshooting flow for the whole module.
It separates the control plane from the data plane so you can identify which
layer is broken instead of treating every failure as "BGP is broken."

The control plane includes:

- Cilium BGP custom resources.
- The BGP session between Cilium and FRR.
- The route that FRR learns for the service IP.

The data plane includes:

- The external client's route toward FRR.
- FRR forwarding traffic toward the Kubernetes node.
- Cilium forwarding traffic to the Service backend.
- The nginx pod actually being ready to serve traffic.

Use this section when a command times out, a service IP is missing, FRR has no
route, or the route exists but the application is still unreachable.

## Suggested Study Order

1. Read [`00-external-networking-and-bgp-foundations/`](00-external-networking-and-bgp-foundations/) before running commands.
2. Build the topology and install Cilium in
   [`01-kind-podman-frr-cilium-setup/`](01-kind-podman-frr-cilium-setup/).
3. Establish BGP peering in [`02-bgp-peering-with-frr/`](02-bgp-peering-with-frr/).
4. Allocate and advertise a service IP in
   [`03-loadbalancer-ip-pools-and-advertisements/`](03-loadbalancer-ip-pools-and-advertisements/).
5. Test the full path in [`04-external-client-testing/`](04-external-client-testing/).
6. Use [`05-bgp-troubleshooting/`](05-bgp-troubleshooting/) to practice reading failures by layer.

## Quick Reference

Important lab values:

| Item | Value |
| --- | --- |
| Podman network | `bgp-kind` |
| Podman network subnet | `172.18.0.0/16` |
| Kind cluster | `cilium-bgp` |
| FRR container | `cilium-bgp-frr` |
| FRR router IP | `172.18.0.254` |
| FRR ASN | `65000` |
| Cilium ASN | `65001` |
| LoadBalancer IP pool | `172.19.100.10-172.19.100.250` |
| Test namespace | `bgp-lab` |
| Test Service | `web` |

Useful checks:

```bash
kubectl get nodes
cilium status
podman ps --filter name=cilium-bgp-frr
podman exec cilium-bgp-frr vtysh -c 'show bgp summary'
kubectl get ciliumbgpclusterconfig,ciliumbgppeerconfig,ciliumbgpadvertisement,ciliumloadbalancerippool
kubectl -n bgp-lab get svc web -o wide
```
