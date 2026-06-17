# CCA Exam Preparation: Cilium In Multi-Pool IPAM Mode

This guide explains how to use Cilium multi-pool IPAM.

Multi-pool IPAM lets Cilium allocate pod IP addresses from multiple named IP pools. This is useful when different workloads should receive addresses from different CIDR ranges.

In this lab you will learn:
- what multi-pool IPAM does
- how it differs from `kubernetes` and `cluster-pool` IPAM
- how to install Cilium with `ipam.mode: multi-pool`
- how to create `CiliumPodIPPool` resources
- how to select an IP pool with pod annotations
- how to verify that pods receive IPs from the expected pool

Official references:
- https://docs.cilium.io/en/stable/network/concepts/ipam/
- https://docs.cilium.io/en/stable/network/kubernetes/ipam-multi-pool/

## Important Notes

- Multi-pool IPAM gives IP addresses to pods.
- It is not the same as LoadBalancer IPAM, which gives external IPs to `LoadBalancer` services.
- Treat this as a fresh-cluster lab. Do not switch an existing study cluster from another IPAM mode to multi-pool unless you are prepared to recreate workloads.
- Cilium multi-pool IPAM uses the `CiliumPodIPPool` custom resource.
- Pods request a pool with the annotation `ipam.cilium.io/ip-pool`.

## Prerequisites

Make sure these tools are installed:

```bash
kind version
kubectl version --client
helm version
cilium version
```

You also need a local container runtime that `kind` can use, such as Docker or Podman.

## What Multi-Pool IPAM Does

Normal `cluster-pool` IPAM has one configured pool of pod CIDRs.

Multi-pool IPAM lets you create multiple named pools, for example:
- `blue-pool`
- `green-pool`
- `database-pool`
- `frontend-pool`

Then pods can request one of those pools by annotation.

Example:

```yaml
metadata:
  annotations:
    ipam.cilium.io/ip-pool: blue-pool
```

Cilium then allocates the pod IP from `blue-pool`.

## When Multi-Pool IPAM Is Useful

Multi-pool IPAM is useful when:
- different teams need different pod CIDR ranges
- workloads need different routing treatment
- you want to separate application groups by IP range
- you need clearer network observability by IP range
- you are studying advanced Cilium IPAM behavior

For basic local Cilium labs, `kubernetes` or `cluster-pool` IPAM is simpler. Multi-pool is a more advanced topic.

## Create A Fresh Kind Cluster

From the `test-environment-setup` folder:

```bash
cd ../test-environment-setup
```

If you already have a `cilium-test` cluster and want to reuse the name, delete it first:

```bash
kind delete cluster --name cilium-test
```

Create the cluster:

```bash
kind create cluster --name cilium-test --config kind.yaml
```

Check nodes:

```bash
kubectl get nodes
```

The nodes may show `NotReady` until Cilium is installed.

## Create Helm Values For Multi-Pool IPAM

Create a file named `multi-pool-values.yaml`:

```yaml
cluster:
  name: kind-cilium-test
kubeProxyReplacement: true
bpf:
  masquerade: true
ipam:
  mode: multi-pool
  operator:
    autoCreateCiliumPodIPPools:
      default:
        ipv4:
          cidrs:
            - 10.10.0.0/16
          maskSize: 27
operator:
  replicas: 1
routingMode: tunnel
tunnelProtocol: vxlan
```

Important:
- `ipam.mode: multi-pool` enables Cilium multi-pool IPAM.
- `kubeProxyReplacement: true` and `bpf.masquerade: true` are required for this multi-pool setup.
- `autoCreateCiliumPodIPPools.default` creates a default pod IP pool during installation.
- Additional address pools are created separately with `CiliumPodIPPool` resources.

## Install Cilium

Add the Cilium Helm repository if you have not already done it:

```bash
helm repo add cilium https://helm.cilium.io
helm repo update
```

Install Cilium:

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.4 \
  --values multi-pool-values.yaml
```

Wait for Cilium:

```bash
cilium status --wait
```

Check the Cilium pods:

```bash
kubectl get pods -n kube-system
```

Check the default pool that Helm created:

```bash
kubectl get ciliumpodippool default -o yaml
```

## Create IP Pools

Create an additional pool in a file named `pod-ip-pools.yaml`:

```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumPodIPPool
metadata:
  name: mars
spec:
  ipv4:
    cidrs:
      - 10.20.0.0/16
    maskSize: 27
```

Apply it:

```bash
kubectl apply -f pod-ip-pools.yaml
```

Check the pools:

```bash
kubectl get ciliumpodippools
kubectl get ciliumpodippools -o yaml
```

What this means:
- `default` can allocate pod IPs from `10.10.0.0/16`
- `mars` can allocate pod IPs from `10.20.0.0/16`
- `maskSize: 27` means Cilium allocates smaller `/27` blocks from each pool

## Create Pods In Different Pools

Create a test namespace:

```bash
kubectl create namespace multi-pool-test
```

Create a file named `test-pods.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: default-client
  namespace: multi-pool-test
spec:
  containers:
    - name: curl
      image: curlimages/curl
      command:
        - sleep
        - "3600"
---
apiVersion: v1
kind: Pod
metadata:
  name: mars-server
  namespace: multi-pool-test
  annotations:
    ipam.cilium.io/ip-pool: mars
  labels:
    app: mars-server
spec:
  containers:
    - name: nginx
      image: nginx
      ports:
        - containerPort: 80
```

Apply it:

```bash
kubectl apply -f test-pods.yaml
```

Wait for the pods:

```bash
kubectl wait --for=condition=Ready pod/default-client pod/mars-server \
  -n multi-pool-test \
  --timeout=120s
```

Check pod IPs:

```bash
kubectl get pods -n multi-pool-test -o wide
```

Expected result:
- `default-client` should have an IP from `10.10.0.0/16`
- `mars-server` should have an IP from `10.20.0.0/16`

## Create A Service And Test Connectivity

Create a service for the server pod:

```bash
kubectl expose pod mars-server \
  -n multi-pool-test \
  --name mars-server \
  --port 80
```

Test connectivity from the default pool pod to the Mars pool service:

```bash
kubectl exec -n multi-pool-test default-client -- curl -I http://mars-server
```

If DNS is slow, get the pod IP and test directly:

```bash
kubectl get pod mars-server -n multi-pool-test -o wide
kubectl exec -n multi-pool-test default-client -- curl -I http://<MARS_SERVER_POD_IP>
```

## Inspect Allocation State

Check Cilium node information:

```bash
kubectl get ciliumnodes -o wide
kubectl get ciliumnodes -o yaml
```

Check pool resources:

```bash
kubectl describe ciliumpodippool default
kubectl describe ciliumpodippool mars
```

Check the pod annotations:

```bash
kubectl get pod default-client -n multi-pool-test -o yaml | grep -A3 annotations
kubectl get pod mars-server -n multi-pool-test -o yaml | grep -A3 annotations
```

Check Cilium status:

```bash
cilium status
```

## Select A Pool At Namespace Level

You can also apply the pool annotation to a namespace.

Create a namespace:

```bash
kubectl create namespace mars-namespace
```

Annotate it:

```bash
kubectl annotate namespace mars-namespace ipam.cilium.io/ip-pool=mars
```

Create an unannotated pod in that namespace:

```bash
kubectl run namespace-client \
  -n mars-namespace \
  --image=curlimages/curl \
  --command -- sleep 3600
```

Check its IP:

```bash
kubectl get pod namespace-client -n mars-namespace -o wide
```

The pod should receive an IP from the `mars` pool because the namespace has the pool annotation.

## Common Mistakes

### Wrong Annotation Key

Use:

```yaml
ipam.cilium.io/ip-pool: blue-pool
```

Do not use a custom annotation name. Cilium only reacts to the expected annotation key.

### Pool Name Does Not Exist

If a pod asks for a pool that does not exist, the pod may stay stuck without an IP.

Check the pod:

```bash
kubectl describe pod <POD_NAME> -n multi-pool-test
```

Check available pools:

```bash
kubectl get ciliumpodippools
```

### CIDR Overlap

Do not overlap pod pools with:
- node IP ranges
- service CIDR ranges
- host network ranges
- other Cilium pod pools

Overlapping CIDRs can create routing problems that are difficult to debug.

## Clean Up

Delete the test namespace:

```bash
kubectl delete namespace multi-pool-test
kubectl delete namespace mars-namespace
```

Delete the pools:

```bash
kubectl delete -f pod-ip-pools.yaml
```

Or delete the whole Kind cluster:

```bash
kind delete cluster --name cilium-test
```

## Good Study Checks

Make sure you can explain and verify:

1. What multi-pool IPAM is
2. Why it is different from `cluster-pool` IPAM
3. What a `CiliumPodIPPool` is
4. How the `ipam.cilium.io/ip-pool` pod annotation works
5. How to check which IP range a pod received
6. How to inspect `CiliumNode` and `CiliumPodIPPool` state
7. Why CIDR overlap is dangerous

## Troubleshooting

If Cilium does not become ready:
- run `cilium status`
- check `kubectl get pods -n kube-system`
- check Cilium logs with `kubectl logs -n kube-system -l k8s-app=cilium`
- check operator logs with `kubectl logs -n kube-system -l name=cilium-operator`

If a pod stays `Pending` or `ContainerCreating`:
- check `kubectl describe pod <POD_NAME> -n multi-pool-test`
- make sure the requested pool exists
- make sure the pool has free addresses
- make sure the annotation is `ipam.cilium.io/ip-pool`

If pods do not get IPs from the expected range:
- check the pod annotation
- check `kubectl get ciliumpodippools -o yaml`
- check `kubectl get ciliumnodes -o yaml`
- recreate the pod after fixing the annotation or pool

If connectivity fails:
- check pod IPs with `kubectl get pods -n multi-pool-test -o wide`
- check Cilium status with `cilium status`
- check whether the service exists with `kubectl get svc -n multi-pool-test`
- test direct pod IP connectivity before testing DNS or service routing
