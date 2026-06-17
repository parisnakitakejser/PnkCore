# CCA Exam Preparation: Network Observability - DNS Visibility

This lab shows how DNS traffic appears in Hubble and why DNS is useful when
debugging service connectivity.

In the default setup from `00-setup-hubble-with-kind`, DNS is most reliable to
observe as normal traffic from the client pod to CoreDNS on port `53`. The
command `hubble observe --protocol dns` may be empty unless Cilium is configured
to emit Layer 7 DNS events. This lab starts with the client flow view so students
can see DNS immediately.

## Learning Goals

- Generate DNS lookups from a pod.
- Filter Hubble output for DNS flows.
- Connect DNS lookups to later application traffic.
- Recognize failed DNS resolution.

## Prerequisites

- Hubble is running.
- A `hubble-demo` namespace exists with a `client` pod.

Create the client if needed by applying the local manifests:

```bash
kubectl apply -f manifests/
kubectl -n hubble-demo wait pod/client --for=condition=Ready --timeout=120s
```

## 1. Watch Client Traffic

Open a terminal and run:

```bash
hubble observe -P --from-pod hubble-demo/client --follow
```

This watches traffic that starts from the `client` pod. DNS normally appears as
UDP traffic from `hubble-demo/client` to a `kube-system/coredns-...` pod on port
`53`.

Keep this command running while you generate DNS lookups in another terminal.
The `--follow` flag is useful here because DNS flows are short-lived. If you run
an observe command after the lookup, the flow may already be outside the recent
output window or hidden by other traffic.

What this command means:

- `--from-pod hubble-demo/client`: only show flows that start from the client
  pod.
- `--follow`: keep the watch open and print new matching flows as they happen.

At this point, the terminal may be empty. That is normal. Hubble is waiting for
new client traffic.

## 2. Generate a Failed DNS Lookup

In another terminal:

```bash
kubectl -n hubble-demo exec client -- sh -c 'curl -m 3 -sS "http://does-not-exist-$(date +%s).hubble-demo.svc.cluster.local"'
```

This command is expected to fail because the name does not exist. For this lab,
that is still useful: it forces the client to ask CoreDNS for a name.

What happens behind the scenes:

1. The `client` pod asks CoreDNS to resolve a unique name.
2. CoreDNS responds that the name does not exist.
3. `curl` fails because it does not get a usable IP address.
4. Hubble can still show the DNS request as traffic to CoreDNS on port `53`.

In the Hubble watch terminal, you should look for UDP traffic between
`hubble-demo/client` and a `kube-system/coredns-...` pod.

Example output:

```text
hubble-demo/client:50292 -> kube-system/coredns-589f44dc88-f4z8r:53 ... FORWARDED (UDP)
hubble-demo/client:41162 -> kube-system/coredns-589f44dc88-bf89b:53 ... FORWARDED (UDP)
hubble-demo/client:45230 -> kube-system/coredns-589f44dc88-f4z8r:53 ... FORWARDED (UDP)
```

This means the client sent DNS queries to CoreDNS. Seeing multiple lines is
normal:

- The client may ask for more than one DNS record type, such as `A` and `AAAA`.
- Kubernetes may have more than one CoreDNS pod, so queries can go to different
  CoreDNS backends.
- The resolver may retry or search through DNS suffixes from the pod's
  `/etc/resolv.conf`.
- The source ports, such as `50292` or `41162`, are temporary UDP source ports
  chosen by the client.

In this basic Hubble view, it is enough to see `client -> coredns:53` with a
`FORWARDED (UDP)` verdict. That proves the DNS request left the client and was
allowed by Cilium.

The command uses `$(date +%s)` so every run asks for a new DNS name. This avoids
confusing results from DNS cache.

## 3. Generate a Successful DNS Lookup

Run a successful lookup directly:

```bash
kubectl -n hubble-demo exec client -- nslookup kubernetes.default.svc.cluster.local
```

Expected command output:

```text
Server:    10.96.0.10
Address:   10.96.0.10:53

Name:      kubernetes.default.svc.cluster.local
Address:   10.96.0.1
```

This means the pod asked the cluster DNS Service at `10.96.0.10` and received
the Kubernetes API Service IP `10.96.0.1`.

Hubble may show output like this:

```text
hubble-demo/client <> kube-system/kube-dns:53 (world) SOCK_XLATE_POINT_UNKNOWN TRACED (UDP)
hubble-demo/client:<port> -> kube-system/coredns-...:53 ... FORWARDED (UDP)
```

These two lines show two useful parts of the same DNS lookup:

- `kube-system/kube-dns:53`: the Kubernetes DNS Service that the pod is trying
  to reach. Pods normally send DNS queries to the cluster DNS Service IP from
  `/etc/resolv.conf`.
- `SOCK_XLATE_POINT_UNKNOWN TRACED (UDP)`: Cilium traced service/socket
  translation. The pod connects to the DNS Service, and Cilium translates that
  Service destination to a real CoreDNS backend pod.
- `kube-system/coredns-...:53`: the actual CoreDNS pod that received the DNS
  query after service translation.
- `FORWARDED (UDP)`: Cilium allowed and forwarded the DNS packet.

So the student should read this as: the client asked the `kube-dns` Service, and
Cilium forwarded the DNS packet to one of the CoreDNS pods.

## 4. Repeat the Failed Lookup

Run another unique failed lookup:

```bash
kubectl -n hubble-demo exec client -- sh -c 'curl -m 3 -sS "http://does-not-exist-$(date +%s).hubble-demo.svc.cluster.local"'
```

The command should fail. That is the point of this step. Hubble should still
show that the client sent DNS traffic to CoreDNS.

What happens behind the scenes:

1. The `client` pod asks CoreDNS for a name that does not exist.
2. CoreDNS responds that the name cannot be resolved.
3. `curl` fails because it never gets a usable IP address.
4. Hubble can still show the UDP request packet on port `53`.

## 5. Inspect DNS Traffic

Run a recent client-flow view:

```bash
hubble observe -P --from-pod hubble-demo/client
```

Look for:

- Source pod: `hubble-demo/client`
- Destination pod: `kube-system/coredns-...`
- Destination port: `53`
- Protocol: `UDP`
- Verdict: `FORWARDED`

Example:

```text
hubble-demo/client:<port> -> kube-system/coredns-...:53 ... FORWARDED (UDP)
```

This proves that the client sent a DNS request to CoreDNS.

This output does not necessarily show the DNS name itself. With the default lab
setup, the important signal is that DNS traffic happened:

- `client -> coredns:53`: the DNS query left the client.
- `FORWARDED`: Cilium allowed the DNS packets.
- `UDP`: DNS commonly uses UDP for normal lookups.

You may not see the CoreDNS response in this filtered view because
`--from-pod hubble-demo/client` focuses on traffic whose source is the client.
The response direction has CoreDNS as the source and the client as the
destination, so it may be hidden by the source filter.

If you want to try a stricter port filter after you have seen DNS in the client
view, run:

```bash
hubble observe -P --from-pod hubble-demo/client --port 53
```

If that is empty in your environment, keep using `--from-pod
hubble-demo/client` and identify DNS lines by `coredns-...:53`.

## 6. Try Layer 7 DNS Visibility

Now try the Layer 7 DNS filter:

```bash
hubble observe -P --namespace hubble-demo --protocol dns
```

If this command is empty, that is expected in this basic setup. It means Hubble
is seeing the DNS packets at L3/L4, but it is not showing parsed DNS query and
response fields as L7 DNS events.

For this lab, the important baseline is:

- `--from-pod hubble-demo/client` shows what the client tried to do.
- DNS lines are the lines going to `kube-system/coredns-...:53`.
- `--protocol dns` only shows parsed DNS events when DNS L7 visibility is
  available.

Later labs can add Cilium policy examples that enable deeper DNS visibility.

## 7. Common Empty Output Cases

If this command is empty:

```bash
hubble observe -P --namespace hubble-demo --protocol dns
```

that is usually because parsed L7 DNS visibility is not enabled. Use this
instead for the basic lab:

```bash
hubble observe -P --from-pod hubble-demo/client
```

If this command is also empty:

```bash
hubble observe -P --from-pod hubble-demo/client --follow
```

check these things:

- Keep the `--follow` command running before generating the DNS lookup.
- Confirm the client pod exists: `kubectl -n hubble-demo get pod client`.
- Rerun the lookup with a unique name to avoid cache confusion.
- Confirm CoreDNS exists: `kubectl -n kube-system get pods -l k8s-app=kube-dns`.
- Confirm Hubble works: `hubble status -P`.

The key distinction for students:

- `--from-pod hubble-demo/client` answers: "What did the client try to do?"
- DNS lines to `coredns-...:53` answer: "Did the client send DNS traffic?"
- `--protocol dns` answers: "Did Hubble receive parsed DNS query/response
  events?"

For this basic DNS lab, `--from-pod hubble-demo/client` is the expected reliable
check.

## Student Check

You should be able to answer:

- Which pod made the DNS request?
- Which CoreDNS pod answered?
- Which port does DNS use?
- Why can client traffic show DNS while `--protocol dns` is empty?
- Why is DNS often checked before debugging HTTP traffic?

## Cleanup

Keep the namespace if you are continuing to later labs.
