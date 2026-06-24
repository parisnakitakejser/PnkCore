# Layer 4 Ingress/Egress Ports

This lab explains how Cilium can allow traffic only on specific Layer 4 ports. In Kubernetes terms, Layer 4 usually means TCP or UDP traffic, and the policy decides whether a selected pod can receive or send traffic on a particular port.

For the Cilium CCA exam, remember this sentence:

> Use `toPorts` to allow specific TCP or UDP ports after the Layer 3 peer has matched.

## Learning Goals

By the end of this lab, you should understand:

- how Cilium separates Layer 3 endpoint selection from Layer 4 port selection
- why `toPorts` is used in both ingress and egress rules
- how a policy can allow one source pod to reach one destination pod only on TCP port `80`
- how to test whether traffic is allowed or denied
- what to look for in a Cilium policy during the CCA exam

## Mental Model

A Cilium policy usually answers two questions:

1. Which pods does this policy apply to?
2. What traffic is allowed for those pods?

The first question is answered by `endpointSelector`.

```yaml
endpointSelector:
  matchLabels:
    app: web
```

This means the policy applies to endpoints with label `app=web`. In this lab, that is the nginx pod named `web`.

The second question is answered by the ingress or egress rules. A Layer 3 rule matches the peer, such as the source pod or destination pod. A Layer 4 rule then narrows that matched traffic to specific ports.

For example:

- Layer 3: allow traffic from pods with `role=client`
- Layer 4: only allow TCP port `80`

Both parts must match. If the source is wrong, traffic is denied. If the port is wrong, traffic is denied.

## Important Cilium Detail

In Cilium policy YAML, the field is called `toPorts` for both ingress and egress.

That can feel surprising at first:

- ingress rule: `fromEndpoints` plus `toPorts`
- egress rule: `toEndpoints` plus `toPorts`

The name `toPorts` means the destination port of the connection. Even when the rule is about ingress, the packet is still going to a destination port on the selected endpoint.

## Files In This Lab

```text
.
|-- kind-config.yaml
|-- manifests
|   |-- web-http-ingress.yaml
|   `-- workloads.yaml
`-- README.md
```

`kind-config.yaml` creates a Kind cluster without the default CNI. This is required because Cilium will be installed as the CNI.

`manifests/workloads.yaml` creates:

- namespace `l4-lab`
- pod `web` running nginx on port `80`
- service `web` pointing to the nginx pod
- pod `client` running a curl image and sleeping

`manifests/web-http-ingress.yaml` creates the Cilium policy used in this lab.

## The Policy

The policy in `manifests/web-http-ingress.yaml` is:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: web-http-ingress
spec:
  endpointSelector:
    matchLabels:
      app: web
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: client
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
```

Read it from top to bottom:

- `kind: CiliumNetworkPolicy` tells Kubernetes this is a Cilium policy object.
- `metadata.name: web-http-ingress` names the policy.
- `endpointSelector.matchLabels.app: web` selects the protected endpoint.
- `ingress` means the rule controls traffic entering the selected endpoint.
- `fromEndpoints.matchLabels.role: client` allows only source endpoints with label `role=client`.
- `toPorts.ports.port: "80"` allows only destination port `80`.
- `protocol: TCP` allows only TCP traffic on that port.

The result is:

```text
client pod -> web pod TCP/80 = allowed
other source -> web pod TCP/80 = denied
client pod -> web pod other TCP port = denied
```

## Step 1: Create A Kind Cluster

Create a local cluster with the provided Kind config:

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name cilium-l4-ports --config kind-config.yaml
```

The config disables the default CNI:

```yaml
networking:
  disableDefaultCNI: true
```

That gives Cilium full responsibility for pod networking and network policy enforcement.

## Step 2: Install Cilium With Helm

Add the Cilium Helm repo and install Cilium:

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set policyEnforcementMode=default
```

Wait for the Cilium DaemonSet to become ready:

```bash
cilium status --wait
```

You can also check the pods:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium
```

Expected result:

- one Cilium pod should run on each Kind node
- the pods should eventually show `Running`

## Step 3: Deploy The Test Workloads

Apply the workload manifest:

```bash
kubectl apply -f manifests/workloads.yaml
```

Wait for both pods:

```bash
kubectl -n l4-lab wait --for=condition=Ready pod/web --timeout=120s
kubectl -n l4-lab wait --for=condition=Ready pod/client --timeout=120s
```

Check the namespace:

```bash
kubectl -n l4-lab get pods,svc
```

Expected result:

- pod `web` is running nginx
- pod `client` is running curl
- service `web` exposes port `80`

## Step 4: Test Before Applying Policy

Before applying any policy, test from the client pod to the web service:

```bash
kubectl -n l4-lab exec client -- curl -sS --connect-timeout 3 web
```

Expected result:

- curl returns the nginx welcome page HTML
- traffic is allowed because no Cilium policy is selecting the `web` endpoint yet

This is important. With `policyEnforcementMode=default`, Cilium does not isolate every pod automatically. Policy enforcement starts for an endpoint when a policy selects it.

## Step 5: Apply The Port-Limited Ingress Policy

Apply the Cilium policy:

```bash
kubectl -n l4-lab apply -f manifests/web-http-ingress.yaml
```

Confirm it exists:

```bash
kubectl -n l4-lab get ciliumnetworkpolicy
```

Expected result:

```text
NAME               AGE
web-http-ingress   ...
```

Now the `web` endpoint is selected by policy. Ingress traffic to `web` must match an allow rule.

## Step 6: Test The Allowed Source And Port

Run the same curl command again:

```bash
kubectl -n l4-lab exec client -- curl -sS --connect-timeout 3 web
```

Expected result:

- curl still returns the nginx welcome page HTML
- this traffic is allowed because the source pod has `role=client`
- this traffic is allowed because the destination port is TCP `80`

The matching path is:

```text
client label role=client
  -> matches fromEndpoints
web service port 80
  -> reaches web pod destination port 80/TCP
  -> matches toPorts
```

## Step 7: Test A Denied Source

Create a temporary pod that does not have the `role=client` label:

```bash
kubectl -n l4-lab run stranger \
  --image=curlimages/curl:8.8.0 \
  --restart=Never \
  --command -- sh -c "sleep 365d"
```

Wait for it:

```bash
kubectl -n l4-lab wait --for=condition=Ready pod/stranger --timeout=120s
```

Try to reach the web service:

```bash
kubectl -n l4-lab exec stranger -- curl -sS --connect-timeout 3 web
```

Expected result:

- the request should time out or fail
- the source pod does not match `fromEndpoints.matchLabels.role=client`
- even though the destination port is `80`, the Layer 3 source requirement is not satisfied

This demonstrates that Layer 4 does not replace Layer 3. The port rule only matters after the peer selection matches.

Remove the temporary pod:

```bash
kubectl -n l4-lab delete pod stranger
```

## Step 8: Understand Service Port Mapping

The `web` service exposes port `80` and forwards to target port `80`:

```yaml
ports:
  - port: 80
    targetPort: 80
```

The policy allows destination port `80`, so the service traffic works. In this lab, the service port and target port are both `80`, which keeps the test simple.

For the CCA exam, always inspect both `port` and `targetPort` when a service is involved. If they are different, be careful about which port the protected endpoint actually receives.

## Ingress Versus Egress

This lab uses ingress policy because it protects the `web` pod from incoming traffic.

Ingress example:

```yaml
endpointSelector:
  matchLabels:
    app: web
ingress:
  - fromEndpoints:
      - matchLabels:
          role: client
    toPorts:
      - ports:
          - port: "80"
            protocol: TCP
```

Meaning:

```text
Allow traffic into app=web from role=client only when the destination port is TCP/80.
```

An equivalent egress-style idea would select the client and control what it can send:

```yaml
endpointSelector:
  matchLabels:
    role: client
egress:
  - toEndpoints:
      - matchLabels:
          app: web
    toPorts:
      - ports:
          - port: "80"
            protocol: TCP
```

Meaning:

```text
Allow traffic out of role=client to app=web only when the destination port is TCP/80.
```

In both cases, `toPorts` is the Layer 4 part.

## Common Mistakes

- Forgetting that `endpointSelector` selects the pod being protected by the policy.
- Thinking `fromEndpoints` selects the destination. In an ingress rule, it selects the source.
- Using `toPorts` without a Layer 3 peer and not understanding the resulting scope.
- Writing the port as a number instead of a string. Cilium examples commonly use `port: "80"`.
- Allowing the correct source but the wrong port.
- Allowing the correct port but the wrong source.
- Confusing service port and container target port.

## CCA Exam Notes

- Use `CiliumNetworkPolicy` for namespace-scoped Cilium policy.
- Use `endpointSelector` to select the endpoints the policy applies to.
- Use `ingress` to control traffic entering selected endpoints.
- Use `egress` to control traffic leaving selected endpoints.
- Use `fromEndpoints` for ingress source selection.
- Use `toEndpoints` for egress destination selection.
- Use `toPorts` for Layer 4 destination port selection in both ingress and egress.
- Ports are usually written as strings, for example `"80"`.
- Protocol is usually `TCP`, `UDP`, or `ANY`.
- Layer 4 rules narrow traffic that already matched the Layer 3 selection.

## Quick Review

The key policy logic from this lab is:

```text
Select app=web.
For ingress to app=web:
  allow from role=client
  allow only destination TCP port 80
```

If you can explain that sentence and point to the matching YAML fields, you understand the main exam concept.

## Cleanup

Delete the Kind cluster when you are done:

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name cilium-l4-ports
```
