# Layer 3 Policies - Services Based (`toServices`)

Service-based Layer 3 policies allow egress traffic to be defined using a Kubernetes Service rather than directly referencing the IP addresses of backend Pods.

Instead of maintaining a list of backend Pod IPs, Cilium can track the Service object and automatically resolve it to the currently active endpoints behind the Service.

This makes policies more resilient in dynamic Kubernetes environments where Pods are frequently replaced, restarted, scaled up, or scaled down.

## Why Use `toServices`?

In Kubernetes, a Service provides a stable virtual endpoint while the backend Pods behind it may change over time.

Without `toServices`, you would need to:

- Track backend Pod IP addresses manually
- Continuously update policies when Pods change
- Risk policy failures when workloads are rescheduled

With `toServices`, the policy follows the Service automatically.

## Sample Policy

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: client-to-web-service
spec:
  endpointSelector:
    matchLabels:
      role: client
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s:k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
            - port: "53"
              protocol: TCP
          rules:
            dns:
              - matchPattern: "*"
    - toServices:
        - k8sService:
            serviceName: web
            namespace: l3-lab
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
```

This selects the client, allows DNS lookups through kube-dns, and allows TCP/80
egress to the Kubernetes Service named `web`.

## Step 1: Create A Kind Cluster

This creates a disposable Kubernetes cluster for the lab.

The point of using a fresh cluster is to make the network policy result easy to
reason about. There are no existing workloads or policies that can affect the
test.

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name cilium-l3-services --config kind-config.yaml
```

## Step 2: Install Cilium With Helm

Cilium is the CNI plugin that enforces the `CiliumNetworkPolicy` resource used
in this example.

The important setting here is `policyEnforcementMode=default`. With default
policy enforcement, Pods are unrestricted until a policy selects them. Once the
`client` Pod is selected by the policy later, only the egress traffic described
by that policy is allowed.

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set policyEnforcementMode=default

cilium status --wait
```

## Step 3: Deploy Test Pods And Service

This deploys three main objects into the `l3-lab` namespace:

- `web` Pod: an nginx Pod that listens on port 80
- `web` Service: a Kubernetes Service that selects the nginx Pod
- `client`: a curl Pod used to test traffic

The point of the Service is that the policy will allow traffic to the Service,
not directly to the current Pod IP. If the `web` Pod is replaced later, the
Service can point to the new backend without changing the policy.

```bash
kubectl apply -f manifests/workloads.yaml

kubectl -n l3-lab wait --for=condition=Ready pod/web --timeout=120s
kubectl -n l3-lab wait --for=condition=Ready pod/client --timeout=120s
```

## Step 4: Test Before Policy To The Service

Before any policy selects the `client` Pod, Cilium allows its traffic by
default.

This command proves the baseline: the client can resolve the Service name
`web`, connect to the Service, and receive the nginx response.

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 3 web
```

Expected result:

- the client reaches nginx

## Step 5: Test Before Policy To The Internet

This command proves the second part of the baseline: before the policy is
applied, the client can also reach outside the cluster.

That matters because later we want to show that the policy allows the internal
Service but does not allow general internet egress.

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 3 https://example.com
```

Expected result:

- the client reaches `example.com`

## Step 6: Apply Service-Based Egress Policy

This policy selects `client` for egress. It allows DNS and egress to the `web` Service.

DNS is allowed because the test uses names such as `web` and `example.com`.
Without DNS egress to kube-dns, failures would be ambiguous: the client might
fail because name resolution is blocked, not because the final destination is
blocked.

The second egress rule allows only TCP/80 traffic to the Kubernetes Service
named `web` in the `l3-lab` namespace. It does not allow arbitrary external IPs.

```bash
kubectl -n l3-lab apply -f manifests/client-to-web-service.yaml
```

## Step 7: Test The Service After Policy

This repeats the internal Service test after the policy selects the `client`
Pod.

The expected success shows the purpose of `toServices`: the client can still use
the stable Kubernetes Service name, while Cilium maps that Service to the
current backend endpoint.

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 3 web
```

Expected result:

- the client still reaches nginx through the `web` Service

## Step 8: Test Internet Egress After Policy

This repeats the internet test after the policy is active.

The expected failure is the important contrast. The policy allows DNS, so the
client can look up `example.com`, but it does not allow the TCP connection to
the external IP returned by DNS. The only application traffic allowed from the
client is TCP/80 to the `web` Service.

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 3 https://example.com
```

Expected result:

- the request fails or times out
- the client cannot reach the internet
- the client can still reach the `web` Service

## CCA Exam Notes

- `toServices` is for egress policy.
- It references a Kubernetes Service, not a Pod label directly.
- It avoids hardcoding backend IP addresses.
- You often still need DNS egress if the client uses a Service DNS name.
- Allowing DNS does not allow the final destination. DNS only lets the client
  resolve names; another egress rule must allow the resolved destination.

## Cleanup

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name cilium-l3-services
```
