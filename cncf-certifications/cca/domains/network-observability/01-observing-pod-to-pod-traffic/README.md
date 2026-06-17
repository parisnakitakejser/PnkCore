# # CCA Exam Preparation: Network Observability - Observing Pod-to-Pod Traffic

This lab creates two pods and uses Hubble to observe traffic between them.

## Learning Goals

- Generate simple pod-to-pod traffic.
- Identify source and destination pods in Hubble.
- Find destination ports and TCP flags.
- Filter flows by namespace and pod.

## Prerequisites

- Complete the root setup guide first.
- Hubble status works:

```bash
hubble status -P
```

## 1. Create the Demo Workloads

This lab uses a small client/server setup:

- `Namespace`: keeps the lab resources isolated from the rest of the cluster.
- `web` pod: runs NGINX and listens on port `80`.
- `web` Service: gives the client a stable DNS name, `http://web`.
- `client` pod: runs a curl image and stays alive so you can execute commands
  from inside the cluster.

Inspect the local manifests:

```bash
ls manifests
cat manifests/namespace.yaml
cat manifests/web-pod.yaml
cat manifests/web-service.yaml
cat manifests/client-pod.yaml
```

Before applying anything, notice that every workload is placed in the
`hubble-demo` namespace. This makes the Hubble output easier to filter later.

Apply the manifests:

```bash
kubectl apply -f manifests/
```

This creates the namespace, the two pods, and the Service. Wait until both pods
are ready before generating traffic:

```bash
kubectl -n hubble-demo wait pod/web --for=condition=Ready --timeout=120s
kubectl -n hubble-demo wait pod/client --for=condition=Ready --timeout=120s
```

Check what was created:

```bash
kubectl -n hubble-demo get pods
kubectl -n hubble-demo get service web
```

The `web` Service should point to port `80`. The `client` pod does not expose a
port; it only sends traffic.

## 2. Generate Traffic

```bash
kubectl -n hubble-demo exec client -- curl -sS http://web >/dev/null
```

This command runs `curl` from inside the `client` pod. The request goes to the
Kubernetes Service named `web`, which forwards the traffic to the `web` pod.

The output is redirected to `/dev/null` because the HTML response is not
important here. The important part is that the request creates network traffic
that Hubble can observe.

## 3. Observe the Namespace

```bash
hubble observe -P --namespace hubble-demo
```

This asks Hubble for recent flows in only the `hubble-demo` namespace. The
namespace filter removes most background cluster traffic.

Look for flows from `client` to `web`. A successful request should include a
`FORWARDED` verdict, which means Cilium allowed and forwarded the traffic.

Example pattern:

```text
hubble-demo/client:<port> -> hubble-demo/web:80 ... FORWARDED
```

You may see more than one line for a single `curl` request. That is normal.
Hubble shows several parts of the connection:

```text
hubble-demo/client:<port> -> kube-system/coredns-...:53 ... FORWARDED (UDP)
hubble-demo/client:<port> <- kube-system/coredns-...:53 ... FORWARDED (UDP)
hubble-demo/client <> hubble-demo/web:80 ... TRACED (TCP)
hubble-demo/client:<port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: SYN)
hubble-demo/client:<port> <- hubble-demo/web:80 ... FORWARDED (TCP Flags: SYN, ACK)
hubble-demo/client:<port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK)
hubble-demo/client:<port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK, PSH)
hubble-demo/client:<port> <- hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK, PSH)
hubble-demo/client:<port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK, FIN)
hubble-demo/client:<port> <- hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK, FIN)
```

What to notice:

- `FORWARDED`: Cilium allowed the packet and forwarded it.
- `TRACED`: Cilium traced the socket or packet translation path. In this lab,
  the `SOCK_XLATE_POINT_UNKNOWN TRACED (TCP)` line can appear when the client
  connects to the `web` Service and Cilium translates the Service destination to
  the backend pod.
- `UDP` to `kube-system/coredns:53`: the client resolves the Service name
  `web` before it opens the TCP connection.
- `TCP Flags: SYN`: the client starts a TCP connection.
- `TCP Flags: SYN, ACK`: the web pod accepts the connection.
- `TCP Flags: ACK`: the connection handshake is acknowledged.
- `TCP Flags: ACK, PSH`: application data is being sent. For this lab, that is
  the HTTP request or response data.
- `TCP Flags: ACK, FIN`: one side is closing the TCP connection.
- `ID:<number>`: Cilium security identity for the source or destination.
- `world`: an identity label that can appear during service/socket translation
  tracing. For this basic lab, focus on the later `client -> web:80` forwarded
  TCP lines.

For this first lab, the most important result is that you can see the client
resolve DNS, connect to `web:80`, exchange data, and close the connection with
`FORWARDED` verdicts.

## 4. Observe One Pod

Traffic involving the client:

```bash
hubble observe -P --namespace hubble-demo --pod client
```

Use this when you know the pod where the request starts. It should show outbound
traffic from `client` and may also show return traffic back to `client`.

Traffic involving the web pod:

```bash
hubble observe -P --namespace hubble-demo --pod web
```

Use this when you know the pod receiving the traffic. It should show traffic
arriving at the `web` pod on port `80`.

## 5. Observe Source and Destination

```bash
hubble observe -P --from-pod hubble-demo/client
hubble observe -P --to-pod hubble-demo/web
```

These filters are more specific:

- `--from-pod hubble-demo/client` shows flows where `client` is the source.
- `--to-pod hubble-demo/web` shows flows where `web` is the destination.

The two filters answer different questions.

`--from-pod hubble-demo/client` shows everything that starts from the client
pod. That can include more than the direct web request:

```text
hubble-demo/client:<dns-port> -> kube-system/coredns-...:53 ... FORWARDED (UDP)
hubble-demo/client <> hubble-demo/web:80 ... SOCK_XLATE_POINT_UNKNOWN TRACED (TCP)
hubble-demo/client:<tcp-port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: SYN)
hubble-demo/client:<tcp-port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK)
hubble-demo/client:<tcp-port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK, PSH)
hubble-demo/client:<tcp-port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK, FIN)
```

This output is useful when you ask: "What did the client try to do?"

What it shows:

- The client first sends a DNS request to CoreDNS on UDP port `53` so it can
  resolve the Service name `web`.
- The `SOCK_XLATE_POINT_UNKNOWN TRACED (TCP)` line is Cilium tracing socket
  translation for the Service connection. The client called `http://web`, and
  Cilium has to translate that Service destination to a backend endpoint.
- The later TCP lines show the actual client-to-web connection on port `80`.
- Only client-originated packet directions are shown. For example, this filter
  does not show every response packet from `web` back to `client`.

`--to-pod hubble-demo/web` is narrower:

```text
hubble-demo/client:<tcp-port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: SYN)
hubble-demo/client:<tcp-port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK)
hubble-demo/client:<tcp-port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK, PSH)
hubble-demo/client:<tcp-port> -> hubble-demo/web:80 ... FORWARDED (TCP Flags: ACK, FIN)
```

This output is useful when you ask: "What traffic arrived at the web pod?"

What it shows:

- DNS traffic is not included because CoreDNS, not `web`, is the destination.
- The socket translation trace may not be included because the filter is focused
  on flows whose destination pod is `hubble-demo/web`.
- The remaining lines are the TCP packets from the client to the web pod.
- The destination is consistently `hubble-demo/web:80`, which confirms traffic
  reached the expected backend pod and port.

When debugging a real problem, start broad with `--namespace`, then narrow down
with `--pod`, `--from-pod`, and `--to-pod`.

Expected pattern:

```text
hubble-demo/client:<port> -> hubble-demo/web:80 ... FORWARDED
```

The source port is usually a random high port chosen by the client. The
destination port should be `80`, because the `web` Service forwards to the NGINX
container on port `80`.

## Student Check

You should be able to answer:

- Which pod is the source?
- Which pod is the destination?
- Which destination port is used?
- What verdict do you see for successful traffic?

## Cleanup

Keep the namespace if you are continuing to the next labs.

If you want to reset:

```bash
kubectl delete namespace hubble-demo
```
