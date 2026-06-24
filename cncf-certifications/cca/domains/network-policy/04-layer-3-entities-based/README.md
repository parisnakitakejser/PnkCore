# Layer 3 Policies - Entity-Based

Entity-based Layer 3 policy uses Cilium's built-in entities to represent well-known network locations and infrastructure components without requiring IP addresses, labels, or endpoint selectors.

Instead of identifying traffic by Pod labels, Service definitions, or CIDR ranges, Cilium can classify traffic based on where it originates or where it is destined. These predefined entities simplify policy creation and make policies easier to maintain.

Entity-based policies are particularly useful when:

- Allowing Pods to communicate with the Kubernetes API Server.
- Restricting Internet access while still allowing internal cluster communication.
- Controlling access to node-level services.
- Defining security boundaries between cluster-internal and external traffic.
- Avoiding manual management of IP addresses or network ranges.

Unlike endpoint-based policies, entities do not rely on Kubernetes labels. Unlike CIDR-based policies, they automatically adapt to infrastructure changes and abstract away underlying IP addresses.

## Common Entities

| Entity | Meaning |
| --- | --- |
| `world` | Traffic outside the cluster. |
| `cluster` | Traffic inside the local cluster. |
| `host` | The local host. |
| `remote-node` | Other nodes in the cluster. |
| `kube-apiserver` | Kubernetes API server traffic where supported. |
| `all` | All traffic. Use carefully. |

The exact available entities can depend on Cilium version and environment, so check the Cilium docs when using them in production.

For example:

- Allowing access to `kube-apiserver` permits communication with the Kubernetes control plane.
- Allowing access to `world` permits communication with external systems outside the cluster.
- Allowing access to `cluster` permits communication with workloads and nodes inside the cluster.

For the Cilium CCA exam, remember this sentence:

> Use entities when the peer is a known category such as `world`, `cluster`, `host`, `remote-node`, or `kube-apiserver`.

## What This Means

Cilium already understands several important infrastructure locations and automatically assigns them predefined identities.

Instead of writing policies based on:

- Pod labels (`fromEndpoints`, `toEndpoints`)
- Kubernetes Services (`toServices`)
- Network ranges (`fromCIDR`, `toCIDR`)

you can reference a built-in entity directly.

This is useful when:

- The destination is the Kubernetes API Server.
- The destination is the Internet.
- The traffic targets Kubernetes nodes.
- The policy should apply regardless of changing IP addresses.
- The target is infrastructure rather than application workloads.

Because entities are maintained by Cilium itself, policies remain stable even when Pods, nodes, or control-plane IP addresses change.

## Sample Policy

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: client-to-world
spec:
  endpointSelector:
    matchLabels:
      role: client
  egress:
    - toEntities:
        - world
```

This selects the client and allows egress to destinations outside the cluster.

## Step 1: Create A Kind Cluster

Create a small Kubernetes cluster for the lab:

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name cilium-l3-entities --config kind-config.yaml
```

Why we do this:

- We need a disposable cluster where Cilium can enforce network policy.
- Kind gives each student the same local environment, so the policy behavior is easier to reproduce.
- The custom `kind-config.yaml` is used so the lab does not depend on an existing cluster.

After this step, `kubectl` should point at the new cluster.

## Step 2: Install Cilium With Helm

Install Cilium as the CNI plugin and policy engine:

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set policyEnforcementMode=default

cilium status --wait
```

Why we do this:

- Kubernetes NetworkPolicy alone does not support Cilium entities such as `world`.
- Cilium must be installed before `CiliumNetworkPolicy` resources can be created and enforced.
- `policyEnforcementMode=default` means Pods are allowed by default until a policy selects them. Once a policy selects a Pod, traffic that is not explicitly allowed by that policy is denied.
- `cilium status --wait` confirms that the Cilium agents are ready before we test connectivity.

This matters for the lab because the client Pod will only become restricted after we apply a Cilium policy that selects it.

## Step 3: Deploy A Client Pod

Create the namespace and the test client:

```bash
kubectl apply -f manifests/workloads.yaml

kubectl -n l3-lab wait --for=condition=Ready pod/client --timeout=120s
```

Why we do this:

- The client Pod gives us a simple place to run `curl` commands from inside the cluster.
- The Pod has the label `role: client`.
- The policy in the next step uses that label in `endpointSelector`, so only this client Pod is affected.
- Waiting for the Pod to be ready avoids confusing policy failures with container startup delays.

The important part of the workload manifest is:

```yaml
metadata:
  labels:
    role: "client"
```

The policy will use this label to decide which endpoint receives the egress rules.

## Step 4: Apply Entity-Based Policy

This policy allows DNS and egress to the `world` entity.

```bash
kubectl -n l3-lab apply -f manifests/client-to-world.yaml
```

Why we do this:

- Applying the policy changes the selected client from "default allowed" to "only the listed egress traffic is allowed".
- The first egress rule allows DNS traffic to CoreDNS in `kube-system`, so the client can resolve names such as `example.com`.
- The second egress rule allows TCP port `443` to the `world` entity.
- `world` means destinations outside the cluster, so we do not need to know the external site's IP address.

The policy has two separate jobs:

```yaml
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
  - toEntities:
      - world
    toPorts:
      - ports:
          - port: "443"
            protocol: TCP
```

The DNS rule is required because `curl https://example.com` first needs to resolve `example.com` to an IP address. The `world` rule then allows the actual HTTPS connection.

## Step 5: Test External HTTPS

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 5 https://example.com
```

Expected result:

- the client can reach an external HTTPS site

Why this works:

- The client Pod is selected by `endpointSelector.matchLabels.role: client`.
- DNS is allowed to CoreDNS on port `53`.
- The resolved destination is outside the cluster, so Cilium classifies it as `world`.
- The connection uses TCP port `443`, which the policy explicitly allows.

You should see the HTML from `example.com`, or at least a successful response body. The exact page content is not important. The important result is that the command succeeds.

## Step 6: Test Something That Should Not Work

Now test external HTTP on port `80`:

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 5 http://example.com
```

Expected result:

- the request fails or times out

Example failure:

```text
curl: (28) Failed to connect to example.com port 80 after 5001 ms: Timeout was reached
```

Why this does not work:

- The destination is still part of the `world` entity.
- DNS resolution is still allowed.
- But the policy only allows TCP port `443` to `world`.
- HTTP uses TCP port `80`, and there is no egress rule allowing that port.

This is the key lesson: `toEntities: world` does not mean "allow all Internet traffic" when it is combined with `toPorts`. In this lab it means "allow traffic to outside-cluster destinations only on the ports listed in the same rule".

## Step 7: Explain The Result

The destination is not selected by labels or IP ranges. It is selected by category:

```yaml
toEntities:
  - world
```

This means the policy allows egress to destinations outside the cluster.

The complete traffic decision is:

| Test | DNS allowed? | Entity match? | Port allowed? | Result |
| --- | --- | --- | --- | --- |
| `https://example.com` | Yes | `world` | TCP `443` yes | Works |
| `http://example.com` | Yes | `world` | TCP `80` no | Fails |

This is useful in real environments because teams often want to allow a workload to reach approved external services over HTTPS without also allowing every external protocol and port.

## CCA Exam Notes

- Entities are built-in Cilium peer categories.
- `world` usually means outside the cluster.
- `cluster` means inside the cluster.
- Entities avoid listing IP ranges for common categories.
- Use entities carefully because they can be broad.

## Cleanup

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name cilium-l3-entities
```
