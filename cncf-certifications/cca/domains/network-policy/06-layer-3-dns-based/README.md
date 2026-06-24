# Layer 3 Policies - DNS Based

DNS-based Layer 3 policy controls egress traffic to external destinations by DNS name.

This is useful because many external services do not have one stable IP address. A service such as
`example.com` may resolve to different IP addresses over time, or to different IP addresses from
different networks. If a policy hardcodes one IP address, the policy may break when DNS returns a
new address.

Cilium solves this with FQDN policy. The policy allows the selected pod to perform DNS lookups,
Cilium observes the DNS answers, and Cilium then allows traffic to the IP addresses learned from
those DNS answers.

For the Cilium CCA exam, remember this sentence:

> Use `toFQDNs` when the external destination is known by DNS name instead of stable IP address.

## What This Lab Teaches

In this lab, a pod named `client` is allowed to reach `example.com` on HTTPS port `443`.

The same pod is not allowed to reach other external DNS names, such as `cilium.io`, because those
names are not listed in the policy. This gives you both an allow case and access denied cases.

The important idea is:

- DNS is allowed so Cilium can see the DNS answer.
- `example.com` is allowed as an FQDN destination.
- HTTPS port `443` is allowed for that destination.
- Other destinations or ports are denied because they are not described by the egress policy.

## Why DNS-Based Policy Needs DNS Visibility

Kubernetes network policies and Cilium network policies ultimately enforce traffic against IP
addresses and ports. DNS names are not present in the packet after the DNS lookup has happened.

For example, when an application runs:

```bash
curl https://example.com
```

the application first asks DNS for the IP address of `example.com`. After that, the connection goes
to an IP address, not to the text name `example.com`.

Cilium must therefore be allowed to observe the DNS lookup. When Cilium sees that `example.com`
resolved to a set of IP addresses, it can temporarily allow traffic to those learned IP addresses.
The learned IPs follow DNS TTL behavior, so the allowed IP set can change when DNS answers change.

## Policy Behavior

The policy in this lab selects only pods with this label:

```yaml
role: client
```

Once an egress policy selects a pod, traffic that is not explicitly allowed by the policy is denied.
That is why the access denied cases are important: they prove that the policy is not simply allowing
all external traffic.

The policy allows two kinds of egress traffic from the selected pod:

1. DNS queries to CoreDNS in the `kube-system` namespace.
2. HTTPS traffic to the IP addresses learned for `example.com`.

## Sample Policy

This is the full policy used in the lab:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: client-to-example-com
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
    - toFQDNs:
        - matchName: example.com
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

The first egress rule allows DNS queries to CoreDNS:

```yaml
toEndpoints:
  - matchLabels:
      k8s:io.kubernetes.pod.namespace: kube-system
      k8s:k8s-app: kube-dns
```

The DNS rule allows Cilium to inspect DNS queries and responses:

```yaml
rules:
  dns:
    - matchPattern: "*"
```

The second egress rule allows the actual external destination:

```yaml
toFQDNs:
  - matchName: example.com
```

The port rule limits the allowed application traffic to HTTPS:

```yaml
ports:
  - port: "443"
    protocol: TCP
```

## Step 1: Create A Kind Cluster

Create a local Kind cluster for the lab:

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name cilium-l3-dns --config kind-config.yaml
```

This creates a temporary Kubernetes cluster where Cilium can be installed and tested without
affecting another environment.

## Step 2: Install Cilium With Helm

Install Cilium:

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set policyEnforcementMode=default

cilium status --wait
```

The important setting is:

```bash
--set policyEnforcementMode=default
```

With default policy enforcement, pods are not isolated until a policy selects them. After a policy
selects a pod, traffic that does not match an allow rule is denied.

## Step 3: Deploy A Client Pod

Deploy the namespace and the test pod:

```bash
kubectl apply -f manifests/workloads.yaml

kubectl -n l3-lab wait --for=condition=Ready pod/client --timeout=120s
```

The pod uses the `curlimages/curl` image so it can make simple HTTP and HTTPS requests. The pod has
this label:

```yaml
role: client
```

That label matters because the Cilium policy uses it in the `endpointSelector`.

## Step 4: Apply DNS-Based Policy

Apply the policy:

```bash
kubectl -n l3-lab apply -f manifests/client-to-example-com.yaml
```

After this policy is applied, the `client` pod is selected by the policy. The pod is now in an
egress allow-list model:

- traffic allowed by the policy is permitted
- traffic not allowed by the policy is denied

## Step 5: Test Allowed Access

Test the allowed DNS name on the allowed port:

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 5 https://example.com
```

Expected result:

- access is allowed
- the request returns content from `example.com`

Why it works:

- the pod can query DNS
- Cilium observes the DNS answer for `example.com`
- `example.com` matches `toFQDNs.matchName`
- the connection uses TCP port `443`, which is allowed

## Step 6: Test Access Denied For Another DNS Name

Try another external DNS name:

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 5 https://cilium.io
```

Expected result:

- access is denied, or the command times out

Why access is denied:

- DNS lookup itself may be allowed because the policy permits DNS queries
- `cilium.io` does not match `toFQDNs.matchName: example.com`
- Cilium does not create an allow entry for the IPs returned for `cilium.io`
- the final HTTPS connection is blocked by the egress policy

This is the main access denied case for the lab. It proves that the policy is limited to the DNS
name in the policy and is not allowing all external HTTPS traffic.

## Step 7: Test Access Denied For The Wrong Port

Try `example.com` over plain HTTP:

```bash
kubectl -n l3-lab exec client -- curl -sS --connect-timeout 5 http://example.com
```

Expected result:

- access is denied, or the command times out

Why access is denied:

- `example.com` is the allowed DNS name
- but plain HTTP uses TCP port `80`
- the policy only allows TCP port `443`
- the destination name matches, but the destination port does not match

This case shows that `toFQDNs` controls the destination identity, while `toPorts` controls which
ports are allowed for that destination.

## Step 8: Explain The Full Result

The successful request to `https://example.com` passes because all required parts match:

- the pod has label `role: client`
- the policy selects that pod
- DNS queries are allowed to CoreDNS
- Cilium observes the DNS answer for `example.com`
- `example.com` matches the FQDN rule
- TCP port `443` matches the port rule

The request to `https://cilium.io` is denied because the DNS name is not allowed:

- the pod may still resolve `cilium.io`
- the returned IPs are not allowed by the FQDN rule
- the HTTPS connection is blocked

The request to `http://example.com` is denied because the port is not allowed:

- the DNS name is allowed
- the destination port is `80`
- the policy only allows port `443`

This distinction is important for the exam. A DNS-based policy is not just "allow this domain".
The policy can also restrict the allowed protocol and port.

## CCA Exam Notes

- Use `toFQDNs` for DNS-name-based egress policy.
- Use `matchName` for one exact DNS name, such as `example.com`.
- Use `matchPattern` for wildcard DNS matching.
- Always allow DNS when using FQDN policy, otherwise Cilium cannot learn the destination IPs.
- DNS-based policy still becomes IP-based enforcement after DNS resolution.
- DNS TTLs matter because learned IPs can expire and be refreshed.
- A selected pod is denied by default for traffic that does not match an egress allow rule.
- Add `toPorts` when the exam question asks for a specific port or protocol.
- Access denied tests are useful because they prove the policy is restrictive.

## Common Mistakes

Do not allow the FQDN but forget DNS:

```yaml
toFQDNs:
  - matchName: example.com
```

Without a DNS egress rule, the pod may not be able to resolve the name, and Cilium may not be able
to learn the IP addresses.

Do not assume `matchName: example.com` also allows every subdomain:

```yaml
matchName: example.com
```

This matches `example.com`, not every name under it. Use a pattern when the requirement is for a
wildcard-style match.

Do not forget the port:

```yaml
toPorts:
  - ports:
      - port: "443"
        protocol: TCP
```

If the policy only allows port `443`, traffic to port `80` is denied even when the DNS name is
correct.

## Cleanup

Delete the lab cluster:

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name cilium-l3-dns
```

This removes the temporary Kind cluster and all resources created for this lab.
