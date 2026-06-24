# Layer 3 Policies - Node Based

Node-based Layer 3 policy is used when the source or destination is a Kubernetes node identity, not a normal pod identity.

For the Cilium CCA exam, remember this sentence:

> Node-based policy selects nodes. Endpoint-based policy selects Pods.

Most Cilium policies use `endpointSelector` to select the protected Pods and `fromEndpoints` or `toEndpoints` to select other Pods. Node-based policy still uses `endpointSelector` for the protected workload, but it uses node selectors such as `fromNodes` or `toNodes` for the node side of the traffic.

This topic is more specialized than normal Pod-to-Pod policy. For normal application traffic, endpoint labels, Services, entities, CIDRs, or DNS names are usually easier to reason about.

## What The Policy Does

The example policy is in `manifests/allow-from-labeled-nodes.yaml`:

```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: allow-from-labeled-nodes
spec:
  endpointSelector:
    matchLabels:
      app: web
  ingress:
    - fromNodes:
        - matchLabels:
            node-lab: allowed
```

Read it as:

- select every Cilium-managed endpoint with `app=web`
- put those selected endpoints into ingress policy enforcement
- allow ingress only when the source node identity has the label `node-lab=allowed`
- deny ingress from node identities that do not match the `fromNodes` selector

The deny behavior is important. There is no separate `deny` rule in this example. The allow rule creates the no-access case because selected endpoints only accept traffic that matches an allow rule.

## Required Cluster Shape

Use a multi-node cluster for this lab. A single-node cluster cannot prove the difference between allowed node traffic and denied node traffic.

This directory includes a Kind config with one control-plane node and three worker nodes:

```yaml
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
```

The three workers are used like this:

- `cilium-l3-nodes-worker`: source node that should have access
- `cilium-l3-nodes-worker2`: source node that should have no access
- `cilium-l3-nodes-worker3`: target node that runs the protected `app=web` Pod

Using a separate target worker keeps the access and no-access tests honest. The test traffic comes from remote host-networked Pods on two different nodes and targets the protected workload on the third worker.

## Create The Cluster

Create the Kind cluster:

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name cilium-l3-nodes --config kind-config.yaml
```

Install Cilium with node selector labels enabled. The `fromNodes` and `toNodes` fields only take effect when Cilium is configured with `enable-node-selector-labels=true`, or the equivalent Helm value `nodeSelectorLabels=true`.

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set policyEnforcementMode=default \
  --set nodeSelectorLabels=true

cilium status --wait
```

Confirm the cluster has the expected nodes:

```bash
kubectl get nodes -o wide
```

Label the workers:

```bash
kubectl label node cilium-l3-nodes-worker node-lab=allowed
kubectl label node cilium-l3-nodes-worker2 node-lab=denied
kubectl label node cilium-l3-nodes-worker3 node-lab=target
```

Before applying the policy, confirm your installed CRD exposes node-based fields:

```bash
kubectl explain ciliumclusterwidenetworkpolicy.spec.ingress
```

Look for `fromNodes`. If the field is missing, stop this lab and treat node-based policy as a conceptual topic for this environment.

## Deploy The Test Workloads

Deploy the protected web server on the target node and the two host-networked curl Pods:

```bash
kubectl apply -f manifests/test-workloads.yaml
kubectl rollout status deployment/web
kubectl wait --for=condition=Ready pod/access-allowed --timeout=90s
kubectl wait --for=condition=Ready pod/access-deny --timeout=90s
```

The curl Pods are host-networked on purpose because node-based policy is about traffic from node identities such as `host` and `remote-node`, not ordinary Pod-to-Pod identities.

## Baseline Before Policy

Before applying the policy, both source nodes should reach the web Service:

```bash
kubectl exec access-allowed -- curl -sS --connect-timeout 3 http://web.default.svc.cluster.local
kubectl exec access-deny -- curl -sS --connect-timeout 3 http://web.default.svc.cluster.local
```

Expected result:

- `access-allowed` returns the nginx HTML page
- `access-deny` also returns the nginx HTML page

This baseline proves the test workload and Service are working before policy changes anything.

## Apply The Policy

Validate and apply the policy:

```bash
kubectl apply --dry-run=server -f manifests/allow-from-labeled-nodes.yaml
kubectl apply -f manifests/allow-from-labeled-nodes.yaml
kubectl get ciliumclusterwidenetworkpolicy allow-from-labeled-nodes
```

The selected `app=web` endpoint is now in ingress default-deny mode except for traffic from nodes labeled `node-lab=allowed`.

## Verify Access And No Access

The allowed node should still connect:

```bash
kubectl exec access-allowed -- curl -sS --connect-timeout 3 http://web.default.svc.cluster.local
```

Expected result:

```text
<!DOCTYPE html>
...
```

The denied node should fail:

```bash
kubectl exec access-deny -- curl -sS --connect-timeout 3 http://web.default.svc.cluster.local
```

Expected result:

```text
curl: (28) Failed to connect ...
```

The exact curl error can vary by timing and datapath behavior, but the important result is:

- `access-allowed` has access
- `access-deny` has no access

If both Pods still have access after applying the policy, check these first:

```bash
kubectl get pods -o wide
kubectl get nodes --show-labels
kubectl describe ciliumclusterwidenetworkpolicy allow-from-labeled-nodes
kubectl -n kube-system get configmap cilium-config -o yaml | grep -E 'node-selector|node-label'
```

The most common issue is that Cilium was installed without node selector labels enabled.

## Compare With Entities

The `remote-node` entity is broader:

```yaml
fromEntities:
  - remote-node
```

That allows traffic from remote nodes as a category.

Node-based selection is more specific:

```yaml
fromNodes:
  - matchLabels:
      node-lab: allowed
```

That allows traffic only from nodes whose node identity contains the selected label.

## CCA Exam Notes

- Pod policy normally uses `endpointSelector`.
- Node-based policy selects node identities with fields such as `fromNodes` and `toNodes`.
- `remote-node` is the broad entity for remote node traffic.
- `fromNodes` is a narrower version of the `remote-node` idea.
- `fromNodes` and `toNodes` require Cilium node selector label support to be enabled.
- A useful access/no-access demo needs at least three worker placements: allowed source, denied source, and protected target.

## Cleanup

```bash
kubectl delete ciliumclusterwidenetworkpolicy allow-from-labeled-nodes --ignore-not-found
kubectl delete -f manifests/test-workloads.yaml --ignore-not-found

KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name cilium-l3-nodes
```
