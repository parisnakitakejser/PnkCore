# CCA Exam Preparation: IPv6 Or Dual-Stack Cluster

This guide explains IPv4, IPv6, and dual-stack Kubernetes clusters with Cilium.

In this lab you will learn:
- what IPv4 is
- what IPv6 is
- what dual-stack means
- how to create an IPv6-only Kind cluster
- how to create a dual-stack Kind cluster
- how to install Cilium with IPv6 enabled
- how to verify pod and service IP families

Official references:
- https://kind.sigs.k8s.io/docs/user/configuration/#ip-family
- https://docs.cilium.io/en/stable/network/kubernetes/ipam-cluster-pool/
- https://docs.cilium.io/en/stable/network/concepts/ipam/kubernetes/

## IPv4, IPv6, And Dual-Stack

### IPv4

IPv4 is the older and most common IP address family.

Example IPv4 address:

```text
10.244.1.25
```

IPv4 addresses are 32-bit addresses. They are usually written as four decimal numbers separated by dots.

Common private IPv4 ranges are:
- `10.0.0.0/8`
- `172.16.0.0/12`
- `192.168.0.0/16`

In Kubernetes, many local clusters use IPv4 pod CIDRs like:

```text
10.244.0.0/16
```

### IPv6

IPv6 is the newer IP address family.

Example IPv6 address:

```text
fd00:10:244::5
```

IPv6 addresses are 128-bit addresses. They are usually written in hexadecimal groups separated by colons.

IPv6 has a much larger address space than IPv4.

In Kubernetes, an IPv6 pod CIDR might look like:

```text
fd00:10:244::/56
```

### Dual-Stack

Dual-stack means the cluster supports both IPv4 and IPv6 at the same time.

In a dual-stack cluster:
- pods can receive both IPv4 and IPv6 addresses
- services can receive IPv4 and IPv6 cluster IPs
- applications can communicate using either address family if the network supports it

Example pod addresses in a dual-stack cluster:

```text
10.244.1.25
fd00:10:244:1::25
```

Dual-stack is useful when:
- you need IPv4 compatibility and IPv6 support
- you are migrating from IPv4 to IPv6
- your environment has both IPv4-only and IPv6-capable systems

## Important Notes

- Treat IPv4-only, IPv6-only, and dual-stack as fresh-cluster labs.
- Do not try to convert a running study cluster from IPv4-only to IPv6 or dual-stack.
- Your host and container runtime must support the IP family you want to test.
- Kind supports `ipv4`, `ipv6`, and `dual` with `networking.ipFamily`.
- On Docker Desktop for macOS or Windows, IPv6 API server access may need `apiServerAddress: 127.0.0.1`.
- AWS ENI IPAM is IPv4-only in Cilium. For IPv6 labs, use a different IPAM mode such as `cluster-pool` or `kubernetes`.

## Prerequisites

Make sure these tools are installed:

```bash
kind version
kubectl version --client
helm version
cilium version
```

You also need a local container runtime that Kind can use, such as Docker or Podman.

## Check Host IPv6 Support

On Linux, check whether IPv6 is enabled:

```bash
sysctl net.ipv6.conf.all.disable_ipv6
```

Expected value:

```text
net.ipv6.conf.all.disable_ipv6 = 0
```

If the value is `1`, IPv6 is disabled on the host.

On macOS and Windows with Docker Desktop, IPv6 behavior depends on Docker Desktop and the VM behind it. If the IPv6 lab fails, use the dual-stack lab first or stay with IPv4 for local testing.

## Lab 1: IPv4-Only Cluster

IPv4 is Kind's default IP family.

Create `kind-ipv4.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
networking:
  ipFamily: ipv4
  disableDefaultCNI: true
```

Create the cluster:

```bash
kind create cluster --name cilium-ipv4 --config kind-ipv4.yaml
```

Create `cilium-ipv4-values.yaml`:

```yaml
cluster:
  name: kind-cilium-ipv4
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

Install Cilium:

```bash
helm repo add cilium https://helm.cilium.io
helm repo update
helm install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.4 \
  --values cilium-ipv4-values.yaml
```

Wait for Cilium:

```bash
cilium status --wait
```

Verify pod addresses:

```bash
kubectl get pods -A -o wide
```

You should see IPv4 pod IPs.

## Lab 2: IPv6-Only Cluster

Create `kind-ipv6.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
networking:
  ipFamily: ipv6
  apiServerAddress: 127.0.0.1
  disableDefaultCNI: true
```

Important:
- `ipFamily: ipv6` makes the Kind cluster IPv6-only.
- `apiServerAddress: 127.0.0.1` keeps the Kubernetes API reachable from the host on macOS and Windows Docker Desktop setups.

Create the cluster:

```bash
kind create cluster --name cilium-ipv6 --config kind-ipv6.yaml
```

Create `cilium-ipv6-values.yaml`:

```yaml
cluster:
  name: kind-cilium-ipv6
ipv4:
  enabled: false
ipv6:
  enabled: true
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv6PodCIDRList:
      - fd00:10:244::/56
    clusterPoolIPv6MaskSize: 64
operator:
  replicas: 1
routingMode: tunnel
tunnelProtocol: vxlan
```

Install Cilium:

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.4 \
  --values cilium-ipv6-values.yaml
```

Wait for Cilium:

```bash
cilium status --wait
```

Verify node and pod addresses:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get ciliumnodes -o yaml
```

You should see IPv6 pod addresses from `fd00:10:244::/56`.

## Lab 3: Dual-Stack Cluster

Create `kind-dualstack.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
networking:
  ipFamily: dual
  disableDefaultCNI: true
```

Create the cluster:

```bash
kind create cluster --name cilium-dualstack --config kind-dualstack.yaml
```

Create `cilium-dualstack-values.yaml`:

```yaml
cluster:
  name: kind-cilium-dualstack
ipv4:
  enabled: true
ipv6:
  enabled: true
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList:
      - 10.244.0.0/16
    clusterPoolIPv4MaskSize: 24
    clusterPoolIPv6PodCIDRList:
      - fd00:10:244::/56
    clusterPoolIPv6MaskSize: 64
operator:
  replicas: 1
routingMode: tunnel
tunnelProtocol: vxlan
```

Install Cilium:

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.4 \
  --values cilium-dualstack-values.yaml
```

Wait for Cilium:

```bash
cilium status --wait
```

Verify pod addresses:

```bash
kubectl get pods -A -o wide
kubectl get ciliumnodes -o yaml
```

In a dual-stack cluster, pods should have both IPv4 and IPv6 allocation state.

## Create A Dual-Stack Test App

Create a namespace:

```bash
kubectl create namespace ip-family-test
```

Create `dualstack-test.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ip-family-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: ip-family-test
spec:
  type: ClusterIP
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
```

Apply it:

```bash
kubectl apply -f dualstack-test.yaml
```

Wait for the app:

```bash
kubectl wait --for=condition=Available deployment/web -n ip-family-test --timeout=120s
```

Check pods and service:

```bash
kubectl get pods -n ip-family-test -o wide
kubectl get svc web -n ip-family-test -o yaml
```

Look for:
- pod IPs
- service `clusterIPs`
- service `ipFamilies`
- service `ipFamilyPolicy`

In a dual-stack cluster, the service should have two cluster IPs: one IPv4 and one IPv6.

## Test Connectivity

Create a client pod:

```bash
kubectl run client \
  -n ip-family-test \
  --image=curlimages/curl \
  --command -- sleep 3600
```

Wait for it:

```bash
kubectl wait --for=condition=Ready pod/client -n ip-family-test --timeout=120s
```

Test service DNS:

```bash
kubectl exec -n ip-family-test client -- curl -I http://web
```

Check DNS answers:

```bash
kubectl run dns-client \
  -n ip-family-test \
  --image=busybox:1.36 \
  --command -- sleep 3600
kubectl wait --for=condition=Ready pod/dns-client -n ip-family-test --timeout=120s
kubectl exec -n ip-family-test dns-client -- nslookup web
```

In a dual-stack cluster, DNS may return both `A` records for IPv4 and `AAAA` records for IPv6.

## Useful Verification Commands

Check Cilium status:

```bash
cilium status
```

Check Cilium config:

```bash
kubectl get configmap cilium-config -n kube-system -o yaml | grep -E 'enable-ipv4|enable-ipv6|ipam'
```

Check node PodCIDRs:

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDRs}{"\n"}{end}'
```

Check Cilium node allocation:

```bash
kubectl get ciliumnodes -o wide
kubectl get ciliumnodes -o yaml
```

Check services:

```bash
kubectl get svc -A
kubectl get svc -A -o yaml | grep -E 'ipFamilies|ipFamilyPolicy|clusterIPs'
```

## Service IP Family Policy

Kubernetes services can choose how they use IP families.

Common values:

| Field | Meaning |
| --- | --- |
| `SingleStack` | service gets one IP family only |
| `PreferDualStack` | service gets both families if the cluster supports it |
| `RequireDualStack` | service must get both families or fail |

Example:

```yaml
spec:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

The order of `ipFamilies` matters. The first family is the primary family for the service.

## Clean Up

Delete the test app:

```bash
kubectl delete namespace ip-family-test
```

Delete a cluster:

```bash
kind delete cluster --name cilium-ipv4
kind delete cluster --name cilium-ipv6
kind delete cluster --name cilium-dualstack
```

Only delete the clusters you created.

## Good Study Checks

Make sure you can explain and verify:

1. What IPv4 is
2. What IPv6 is
3. What dual-stack means
4. How Kind chooses `ipv4`, `ipv6`, or `dual`
5. How Cilium enables IPv6 with Helm values
6. How pod CIDRs differ between IPv4 and IPv6
7. How dual-stack services use `clusterIPs`, `ipFamilies`, and `ipFamilyPolicy`
8. Why changing IP family is best done with a fresh cluster

## Troubleshooting

If the Kind IPv6 cluster fails:
- check whether the host supports IPv6
- keep `apiServerAddress: 127.0.0.1` in the Kind config on macOS or Windows
- try the dual-stack lab before the IPv6-only lab
- check Docker or Podman IPv6 support

If Cilium does not become ready:
- run `cilium status`
- check `kubectl get pods -n kube-system`
- check Cilium logs with `kubectl logs -n kube-system -l k8s-app=cilium`
- check operator logs with `kubectl logs -n kube-system -l name=cilium-operator`

If pods do not get IPv6 addresses:
- check `ipv6.enabled: true`
- check `ipam.operator.clusterPoolIPv6PodCIDRList`
- check `kubectl get ciliumnodes -o yaml`
- check that the cluster was created with `ipFamily: ipv6` or `ipFamily: dual`

If a dual-stack service only gets one IP:
- check that the cluster is really dual-stack
- check `ipFamilyPolicy`
- use `PreferDualStack` or `RequireDualStack`
- inspect the service with `kubectl get svc <SERVICE_NAME> -o yaml`
