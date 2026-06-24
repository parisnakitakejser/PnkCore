# Layer 3 Policies - Egress Peers And Ports

Layer 3 policy selects network peers. A peer can be selected by Kubernetes labels, Cilium endpoint labels, entities, or IP/CIDR ranges.

For the Cilium CCA exam, remember this sentence:

> Use CIDR policy when the peer is not a Cilium-managed endpoint and you have a stable IP range.

## What This Means

Layer 3 policy answers the question:

> Which network peer is this Pod allowed to talk to?

With normal Kubernetes or Cilium label-based policy, the peer is usually another Pod selected by labels.

With CIDR policy, the peer is an IP range.

CIDR policy is useful when the destination is outside the cluster and does not have Kubernetes labels. If the destination is another Pod, prefer endpoint labels instead of hard-coding Pod IPs.

Common examples:

- a database outside the cluster
- an external API with fixed IP ranges
- a corporate network subnet
- a private address range reached over VPN
- a known public IP used by a third-party service

CIDR policy is less flexible than label-based policy because IP addresses can change. If the external service moves to a new IP address, the policy does not automatically follow it.

## Important Default-Deny Detail

This lab uses an egress policy. Egress means traffic leaving the selected Pod.

The policy selects this Pod:

```yaml
endpointSelector:
  matchLabels:
    role: client
```

After an egress policy selects a Pod, egress for that Pod becomes allow-list based.

That means:

- traffic matching an egress allow rule is allowed
- traffic not matching any egress allow rule is denied
- this is still true even when the policy does not contain an explicit `deny` section

In this lesson, "deny" means "not allowed by the allow list."

The sample manifest allows:

- DNS to CoreDNS, so the client can resolve names
- TCP port 80 to the Pod labeled `role=server`

It does not allow:

- TCP port 443 to the same server Pod
- TCP port 80 to `google.com`
- TCP port 443 to `google.com`
- arbitrary external traffic

## Sample Policy

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: client-to-server-http
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
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: l3-lab
            role: server
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
```

This policy allows the selected client Pod to send HTTP traffic to one specific server Pod.

The successful test uses another Pod because it is stable and fully under your control. For a Kubernetes-managed Pod, endpoint labels are the correct Cilium policy primitive.

CIDR rules still matter for external IP ranges. `/32` means one single IPv4 address.

Examples:

- `142.250.74.110/32` means only `142.250.74.110`
- `10.0.0.0/24` means `10.0.0.0` through `10.0.0.255`
- `10.0.0.0/8` means a much larger private range

## `toCIDR` Versus `toCIDRSet`

Use `toCIDR` for a simple list of allowed CIDRs.

Use `toCIDRSet` when you need exceptions with `except`.

Example:

```yaml
toCIDRSet:
  - cidr: 10.0.0.0/8
    except:
      - 10.96.0.0/12
```

This allows `10.0.0.0/8` except the excluded range.

Use this when most of a range should be allowed, but a smaller range inside it must stay blocked.

## Step 1: Create A Kind Cluster

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name cilium-l3-cidr --config kind-config.yaml
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

## Step 3: Deploy The Client And Server Pods

This creates:

- namespace `l3-lab`
- Pod `client`
- label `role=client`
- Pod `server`
- label `role=server`

```bash
kubectl apply -f manifests/workloads.yaml

kubectl -n l3-lab wait --for=condition=Ready pod/client --timeout=120s
kubectl -n l3-lab wait --for=condition=Ready pod/server --timeout=120s
```

Before applying any policy, the client has no Cilium egress policy selecting it.

Test that the client can reach the server Pod before policy is added:

```bash
SERVER_IP=$(kubectl -n l3-lab get pod server -o jsonpath='{.status.podIP}')
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 5 "http://${SERVER_IP}"
```

Expected result:

- the request should return the default NGINX HTML
- no egress restriction is active yet

You can also test that general external traffic works before policy is added:

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 5 http://google.com
```

Expected result:

- the request should usually work if your local network allows internet access
- no egress restriction is active yet

## Step 4: Apply The Egress Policy

This policy allows DNS and HTTP to the `server` Pod.

```bash
kubectl -n l3-lab apply -f manifests/client-to-server-http.yaml
```

After this policy is applied, the `client` Pod is no longer allowed to send arbitrary egress traffic. It can only send egress traffic that matches the policy.

## Step 5: Test Allowed Pod HTTP Traffic

```bash
SERVER_IP=$(kubectl -n l3-lab get pod server -o jsonpath='{.status.podIP}')
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 5 "http://${SERVER_IP}"
```

Expected result:

- traffic is allowed because the destination Pod matches `role=server`
- traffic is allowed because the destination port is TCP `80`

## Step 6: Test Denied Traffic

Try Google on HTTP:

```bash
kubectl -n l3-lab exec client -- curl -v --connect-timeout 5 http://google.com
```

Expected result:

- DNS is allowed, so the name can resolve
- traffic should be denied because the resolved Google IP is not the allowed `server` Pod
- curl usually times out

Try Google on HTTPS:

```bash
kubectl -n l3-lab exec client -- curl -v --connect-timeout 5 https://google.com
```

Expected result:

- DNS is allowed, so the name can resolve
- traffic should be denied because the resolved Google IP is not the allowed `server` Pod
- traffic should also be denied because the policy allows TCP port `80`, not TCP port `443`
- curl usually times out

Try the allowed server Pod on HTTPS:

```bash
SERVER_IP=$(kubectl -n l3-lab get pod server -o jsonpath='{.status.podIP}')
kubectl -n l3-lab exec client -- curl -vk --connect-timeout 5 "https://${SERVER_IP}"
```

Expected result:

- traffic should be denied because the destination port is TCP `443`
- the policy only allows TCP `80` to the server Pod
- curl usually times out

This shows two different checks:

- Layer 3 check: is the destination peer allowed?
- Layer 4 check: is the destination port allowed?

Both must match the policy.

## Why A Deny Test Might Not Look Denied

Sometimes students run a denied test and get a result they do not expect. These are the common reasons.

### The Pod Is Not Selected By The Policy

The policy only applies to endpoints selected by `endpointSelector`.

Check the client labels:

```bash
kubectl -n l3-lab get pod client --show-labels
```

The Pod must have:

```text
role=client
```

If the label is missing or different, the policy does not select the Pod. If the policy does not select the Pod, the egress allow list is not enforced for that Pod.

### The Policy Is In The Wrong Namespace

`CiliumNetworkPolicy` is namespaced.

This command applies the policy to `l3-lab`:

```bash
kubectl -n l3-lab apply -f manifests/client-to-server-http.yaml
```

If you apply it to another namespace, it will not select the `client` Pod in `l3-lab`.

Check where the policy exists:

```bash
kubectl get cnp -A
```

### Another Policy Also Allows The Traffic

Cilium policies are additive for allowed traffic.

If one policy allows a flow, and another policy does not mention that flow, the traffic can still be allowed.

This matters when a cluster already has other policies installed.

Check policies in the namespace:

```bash
kubectl -n l3-lab get cnp
kubectl -n l3-lab get networkpolicy
```

For a clean lab, use a fresh Kind cluster.

### You Tested DNS Instead Of The Final Peer

This lesson allows DNS so that hostname tests can resolve. DNS resolution does not mean the final connection is allowed.

If you run:

```bash
kubectl -n l3-lab exec client -- curl -v http://google.com
```

the name `google.com` may resolve successfully, but the HTTP connection should still fail because the policy does not allow egress to Google's IPs.

DNS policy and connection policy are separate checks.

For the controlled allowed test, use the server Pod IP:

```bash
SERVER_IP=$(kubectl -n l3-lab get pod server -o jsonpath='{.status.podIP}')
kubectl -n l3-lab exec client -- curl -v "http://${SERVER_IP}"
```

Use DNS-based policy when the hostname is the stable part and the IP addresses may change.

### The External Destination Is Not Reachable

A failed curl does not always mean "denied by policy."

It can also mean:

- your local network blocks the destination
- the remote IP is not serving HTTP
- the remote server changed behavior
- the Kind cluster cannot reach the internet

That is why the exam concept matters more than the public IP used in the lab.

### The Test Uses A Different Protocol Or Port

The manifest allows TCP port `80`.

It does not allow:

- ICMP ping
- TCP port `443`
- UDP traffic to the peer

So these tests may fail even though the peer is correct:

```bash
SERVER_IP=$(kubectl -n l3-lab get pod server -o jsonpath='{.status.podIP}')
kubectl -n l3-lab exec client -- ping -c 3 "${SERVER_IP}"
kubectl -n l3-lab exec client -- curl -v "https://${SERVER_IP}"
```

The reason is that the protocol or port does not match the allow rule.

## How To Read The Policy Like The Exam

When you see an egress policy, read it in this order:

1. Which Pods does `endpointSelector` select?
2. Is the traffic `ingress` or `egress`?
3. Which peers are allowed?
4. Are ports restricted with `toPorts`?
5. Is DNS also needed for the application test?

For this lab:

- selected Pod: `client`
- direction: egress
- allowed destination: Pod `server`
- allowed application port: TCP `80`
- DNS: allowed separately to CoreDNS

## CCA Exam Notes

- CIDR policy selects IP ranges directly.
- `/32` means exactly one IPv4 address.
- Prefer endpoint labels or Services when the destination is Kubernetes-managed.
- `toCIDR` is simple allow-list CIDR matching.
- `toCIDRSet` supports exclusions with `except`.
- CIDR policy is best when IP ranges are stable.
- After an egress policy selects a Pod, unmatched egress traffic is denied by default.
- A denied connection often appears as a timeout, not a clean "denied" message.
- If a deny test does not behave as expected, check Pod labels, namespace, other policies, DNS results, and port/protocol.

## Cleanup

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name cilium-l3-cidr
```
