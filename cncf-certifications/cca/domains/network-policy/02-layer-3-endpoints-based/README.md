# Layer 3 Policies - Endpoints Based

## Endpoint-Based Layer 3 Policy

Endpoint-based Layer 3 policies control communication between workloads by selecting endpoints using Kubernetes labels rather than IP addresses.

Cilium assigns a unique security identity to each managed endpoint based on its labels. When a policy references an endpoint, Cilium evaluates the endpoint identity instead of relying on a specific IP address.

This approach is considered the most Kubernetes-native method of implementing Layer 3 security because Pods are frequently created, destroyed, and assigned new IP addresses. Policies based on labels continue to work even when Pod IPs change.

### Why Use Endpoint-Based Policies?

- No dependency on Pod IP addresses
- Automatically adapts to Pod recreation and scaling
- Easier to maintain than IP-based rules
- Aligns with Kubernetes label-driven architecture
- Uses Cilium security identities for efficient policy enforcement

### Common Policy Objects

#### `fromEndpoints`

Controls which endpoints are allowed to send traffic **to** the selected endpoint.

Example:

```yaml
ingress:
  - fromEndpoints:
      - matchLabels:
          app: frontend
```

## What This Means

Endpoint-based policy is ideal for Pod-to-Pod traffic.

Example:

- `web` has label `app=web`
- `good-client` has label `role=allowed`
- `bad-client` has label `role=blocked`

You can allow only `good-client` to reach `web` without knowing any Pod IP addresses.

## Sample Policy

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-good-client-to-web
spec:
  endpointSelector:
    matchLabels:
      app: web
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: allowed
```

This selects `web` as the protected endpoint and allows ingress from endpoints with `role=allowed`.

## Step 1: Create A Kind Cluster

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name cilium-l3-endpoints --config kind-config.yaml
```

## Step 2: Install Cilium With Helm

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set policyEnforcementMode=default

cilium status --wait
```

## Step 3: Deploy Test Pods

```bash
kubectl apply -f manifests/workloads.yaml

kubectl -n l3-lab wait --for=condition=Ready pod/web --timeout=120s
kubectl -n l3-lab wait --for=condition=Ready pod/good-client --timeout=120s
kubectl -n l3-lab wait --for=condition=Ready pod/bad-client --timeout=120s
```

## Step 4: Test Before Policy

```bash
kubectl -n l3-lab exec good-client -- curl -sS --connect-timeout 3 web
kubectl -n l3-lab exec bad-client -- curl -sS --connect-timeout 3 web
```

Expected result:

- both clients reach `web`

## Step 5: Apply Endpoint-Based Policy

```bash
kubectl -n l3-lab apply -f manifests/allow-good-client-to-web.yaml
```

## Step 6: Test After Policy

```bash
kubectl -n l3-lab exec good-client -- curl -sS --connect-timeout 3 web
kubectl -n l3-lab exec bad-client -- curl -sS --connect-timeout 3 web
```

Expected result:

- `good-client` succeeds
- `bad-client` fails

## CCA Exam Notes

- Endpoint-based policy uses labels, not IP addresses.
- `endpointSelector` selects the endpoints being protected.
- `fromEndpoints` selects allowed sources for ingress.
- `toEndpoints` selects allowed destinations for egress.
- This is usually preferred for Pod-to-Pod policy.

## Cleanup

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name cilium-l3-endpoints
```
