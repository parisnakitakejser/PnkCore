# CCA Exam Preparation: Cilium In IPAM Mode

This guide explains Cilium IP Address Management, usually called IPAM.

IPAM controls how pods get IP addresses in a Kubernetes cluster. Cilium needs an IPAM mode so every pod can receive a unique IP and communicate with other pods, services, and external networks.

In this lab you will learn:
- what IPAM does
- how to check the current Cilium IPAM mode
- how `kubernetes` IPAM mode works
- how `cluster-pool` IPAM mode works
- how to install Cilium with a specific IPAM mode
- how to verify pod CIDR allocation

Official reference:
- https://docs.cilium.io/en/stable/network/concepts/ipam/

## Important Notes

- Do not confuse Cilium IPAM with Cilium LoadBalancer IPAM.
- Cilium IPAM gives IP addresses to pods.
- LoadBalancer IPAM gives external IP addresses to `LoadBalancer` services.
- The safest way to change Cilium IPAM mode is to create a fresh cluster and install Cilium again with the new IPAM mode.
- Avoid changing IPAM mode on an existing cluster unless you know the migration path for that environment.

## Prerequisites

You should already have the local Cilium test cluster from:

```bash
cd ../test-environment-setup
```

Check that Cilium is healthy:

```bash
cilium status --wait
kubectl get nodes
```

The local setup in this repo uses this Helm value:

```yaml
ipam:
  mode: kubernetes
```

That means the cluster is using Kubernetes host-scope IPAM.

## What IPAM Does

When a pod starts, it needs an IP address.

Cilium IPAM decides where that IP comes from.

The main modes to understand for CCA study are:

| Mode | What It Means | Good For |
| --- | --- | --- |
| `kubernetes` | Kubernetes assigns each node a PodCIDR, and Cilium allocates pod IPs from that node CIDR | Simple local clusters, Kind, kubeadm-style clusters |
| `cluster-pool` | Cilium manages a cluster-wide pool and assigns per-node CIDRs from that pool | Cilium-managed pod CIDR allocation |
| `multi-pool` | Cilium can allocate pod IPs from multiple named pools | Advanced multi-tenant or special routing setups |
| cloud IPAM modes | Cloud provider APIs assign pod IPs | AWS ENI, Azure, GKE, and similar cloud environments |

For local CCA labs, focus on `kubernetes` and `cluster-pool`.

## Check The Current IPAM Mode

Check Cilium status:

```bash
cilium status
```

Look for the `IPAM` line in the output.

You can also inspect the Cilium ConfigMap:

```bash
kubectl get configmap cilium-config -n kube-system -o yaml | grep -i ipam
```

Another useful check is the Cilium node object:

```bash
kubectl get ciliumnodes
kubectl get ciliumnode -o wide
```

If your cluster does not have the short name, use the full resource name:

```bash
kubectl get ciliumnodes.cilium.io
```

## Kubernetes Host-Scope IPAM

In `kubernetes` IPAM mode, Kubernetes gives every node a PodCIDR.

Cilium then allocates pod IPs from the PodCIDR assigned to the node where the pod is running.

The flow is:

1. Kubernetes assigns a PodCIDR to each node
2. Cilium reads the node PodCIDR from the Kubernetes API
3. Cilium allocates pod IPs from that node's PodCIDR

Check each node's PodCIDR:

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
```

Check pod IPs:

```bash
kubectl get pods -A -o wide
```

The pod IPs should come from the node PodCIDR ranges.

## Install Cilium With Kubernetes IPAM

If you are creating a fresh cluster, use this Helm values file:

```yaml
cluster:
  name: kind-cilium-test
ipam:
  mode: kubernetes
operator:
  replicas: 1
routingMode: tunnel
tunnelProtocol: vxlan
```

Install with Helm:

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.4 \
  --values helm-values.yaml
```

Or upgrade an existing Helm release that already uses compatible networking:

```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.4 \
  --values helm-values.yaml
```

Wait for Cilium:

```bash
cilium status --wait
```

## Cluster-Pool IPAM

In `cluster-pool` IPAM mode, Cilium manages the pod CIDR pool.

Instead of depending on Kubernetes node PodCIDRs, Cilium has a cluster-wide CIDR range. The Cilium operator splits that range into smaller per-node CIDRs.

The flow is:

1. You configure a cluster-wide pod CIDR pool
2. The Cilium operator assigns a smaller CIDR to each node
3. Cilium agents allocate pod IPs from the node's assigned Cilium CIDR

This is the default IPAM mode in many Cilium installations.

## Install Cilium With Cluster-Pool IPAM

For a fresh local Kind cluster, create a Helm values file like this:

```yaml
cluster:
  name: kind-cilium-test
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList:
      - 10.244.0.0/16
    clusterPoolIPv4MaskSize: 24
operator:
  replicas: 1
routingMode: tunnel
tunnelProtocol: vxlan
```

This means:
- `10.244.0.0/16` is the full pool for pod IPs
- each node receives a `/24` from that pool
- each `/24` gives up to 256 addresses before Kubernetes and Cilium reservations

Install Cilium:

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.4 \
  --values helm-values.yaml
```

Wait for Cilium:

```bash
cilium status --wait
```

Check the Cilium nodes:

```bash
kubectl get ciliumnodes -o wide
```

Inspect the allocated CIDRs:

```bash
kubectl get ciliumnodes -o yaml
```

Look for IPAM allocation fields and pod CIDR information in the output.

## Compare Kubernetes IPAM And Cluster-Pool IPAM

With `kubernetes` IPAM:
- Kubernetes owns node PodCIDR assignment
- Cilium waits for the node PodCIDR
- `kubectl get nodes -o yaml` shows the important PodCIDR information

With `cluster-pool` IPAM:
- Cilium owns pod CIDR allocation
- the Cilium operator assigns per-node CIDRs
- `kubectl get ciliumnodes -o yaml` shows the important allocation information

Use these commands to compare:

```bash
kubectl get nodes -o wide
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
kubectl get ciliumnodes -o wide
kubectl get pods -A -o wide
cilium status
```

## Create Test Pods

Create a test namespace:

```bash
kubectl create namespace ipam-test
```

Run two pods:

```bash
kubectl run client -n ipam-test --image=curlimages/curl --command -- sleep 3600
kubectl run server -n ipam-test --image=nginx
```

Wait for both pods:

```bash
kubectl wait --for=condition=Ready pod/client pod/server -n ipam-test --timeout=120s
```

Check their IP addresses:

```bash
kubectl get pods -n ipam-test -o wide
```

Create a Service for the server pod:

```bash
kubectl expose pod server -n ipam-test --port 80
```

Test connectivity:

```bash
kubectl exec -n ipam-test client -- curl -I http://server
```

If DNS does not resolve immediately, get the server pod IP and test directly:

```bash
kubectl get pod -n ipam-test server -o wide
kubectl exec -n ipam-test client -- curl -I http://<SERVER_POD_IP>
```

Clean up:

```bash
kubectl delete namespace ipam-test
```

## Start Over With A Different IPAM Mode

For study labs, the cleanest path is to recreate the cluster.

Delete the cluster:

```bash
kind delete cluster --name cilium-test
```

Create it again:

```bash
kind create cluster --name cilium-test --config kind.yaml
```

Install Cilium again with the IPAM mode you want to test.

## Good Study Checks

Make sure you can explain and verify:

1. What IPAM means in Cilium
2. The difference between pod IPAM and LoadBalancer IPAM
3. What `ipam.mode: kubernetes` does
4. What `ipam.mode: cluster-pool` does
5. Where to check node PodCIDRs
6. Where to check Cilium node allocation state
7. Why changing IPAM mode is usually a fresh-cluster task

## Troubleshooting

If Cilium does not become ready:
- run `cilium status`
- check `kubectl get pods -n kube-system`
- check Cilium logs with `kubectl logs -n kube-system -l k8s-app=cilium`
- check operator logs with `kubectl logs -n kube-system -l name=cilium-operator`

If pods do not get IP addresses:
- check the configured IPAM mode
- check `kubectl get ciliumnodes -o yaml`
- check whether node PodCIDRs exist with `kubectl get nodes -o yaml`
- make sure your cluster-wide pod CIDR does not overlap with your node, service, or host network ranges

If you are using `kubernetes` IPAM and nodes have no PodCIDR:
- check the Kubernetes controller manager configuration
- make sure the cluster was created with pod CIDR allocation enabled
- for local study, recreate the Kind cluster from the known working `kind.yaml`

If you are using `cluster-pool` IPAM and allocation fails:
- check `ipam.operator.clusterPoolIPv4PodCIDRList`
- check `ipam.operator.clusterPoolIPv4MaskSize`
- make sure the pool is large enough for all nodes
- check the Cilium operator logs
