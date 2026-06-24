# Debugging Dropped Flows

This lab teaches how to simulate dropped traffic with a temporary Cilium policy,
look for the resulting `DROPPED` flows with Hubble, and read the reason for the
drop.

A failed connection and a `DROPPED` flow are not always the same thing. This is
an important troubleshooting idea:

- A command can fail because DNS did not resolve.
- A command can fail because the destination refused the connection.
- A command can fail because the destination did not answer before timeout.
- A command can fail because the route is wrong or missing.
- A command can fail because Cilium intentionally dropped the packet.

Hubble only shows `DROPPED` when Cilium actually drops the packet. If `curl`
fails but Hubble does not show a dropped flow, the failure still matters, but it
may not be a Cilium drop. This lab helps you practice that difference by showing
both a deterministic Cilium drop and a failed request that may not be a drop.

## Learning Goals

By the end of this lab, you should be able to:

- Filter Hubble output for `DROPPED` flows.
- Generate traffic from a test client pod that Cilium intentionally drops.
- Explain why a failed connection is not always a Cilium drop.
- Inspect recent Hubble flows when a live watch does not show anything.
- Read the source, destination, protocol, verdict, and drop reason from a flow.

## 1. Create the kind Cluster and Lab Workload

This lab is designed for a local kind cluster. The root of this lab contains a
`kind-config.yaml` file that creates a cluster prepared for Cilium:

```bash
kind create cluster --name hubble-lab --config kind-config.yaml
```

The kind config creates two nodes and disables the default CNI and kube-proxy:

- `role: control-plane`: creates the Kubernetes control-plane node.
- `role: worker`: creates one worker node for running workloads.
- `disableDefaultCNI: true`: kind will not install its default networking plugin.
- `kubeProxyMode: none`: kube-proxy is disabled so Cilium can provide kube-proxy
  replacement behavior.

This matters because Cilium should be the component handling pod networking in
this lab. If kind installs its default CNI first, the cluster will not match the
networking path students are expected to observe.

Validate that `kubectl` points at the new cluster:

```bash
kubectl config current-context
kubectl get nodes
```

Expected context:

```text
kind-hubble-lab
```

You should see one control-plane node and one worker node. The nodes may be
`NotReady` until Cilium is installed. That is expected because the cluster does
not have a CNI yet.

Install Cilium and wait for it to become ready:

```bash
cilium install --version 1.19.5
cilium status --wait
```

Enable Hubble and wait again:

```bash
cilium hubble enable
cilium status --wait
```

Check that the Hubble CLI can reach Hubble Relay:

```bash
hubble status -P
```

Expected result:

```text
Healthcheck (via 127.0.0.1:4245): Ok
Connected Nodes: <ready>/<total>
```

You also need these local tools installed:

- A kind-supported container runtime, such as Docker or Podman.
- `kind`
- `kubectl`
- The `cilium` CLI.
- The `hubble` CLI.

This lab uses one namespace and one pod:

- `hubble-demo` namespace
- `client` pod running the `curlimages/curl` image

Create them with the local manifests:

```bash
kubectl apply -f manifests/
```

Wait until the client pod is ready:

```bash
kubectl -n hubble-demo wait pod/client --for=condition=Ready --timeout=120s
```

Check the pod if the wait command fails:

```bash
kubectl -n hubble-demo get pod client -o wide
kubectl -n hubble-demo describe pod client
```

Why this matters:

- Hubble observes network flows from real workloads.
- The `client` pod gives you a controlled place to run `curl`.
- The lab does not need a server pod because the drop is simulated with an
  egress deny rule to an external IP address.

## 2. Start Watching Dropped Flows

Open one terminal and run:

```bash
hubble observe -P --namespace hubble-demo --verdict DROPPED --follow
```

Keep this command running.

What each option means:

- `observe`: ask Hubble for network flow records.
- `-P`: print flows in a compact, human-readable format.
- `--namespace hubble-demo`: only show flows related to the lab namespace.
- `--verdict DROPPED`: only show flows where the verdict is `DROPPED`.
- `--follow`: keep the command open and print new matching flows as they happen.

Empty output is normal at this point. It means Hubble has not seen a matching
drop yet. It does not mean Hubble is broken.

This command is intentionally narrow. It hides all allowed traffic and only
shows traffic that Cilium reports as dropped. Narrow filters are useful during
debugging because they reduce noise, but they can also hide useful context. You
will use a broader query later if no drop appears.

## 3. Simulate a Cilium Drop

Create a temporary policy that denies one specific egress flow from the `client`
pod:

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: simulate-dropped-flow
  namespace: hubble-demo
spec:
  endpointSelector:
    matchLabels:
      app: client
  egressDeny:
    - toCIDRSet:
        - cidr: 1.1.1.1/32
EOF
```

What this policy does:

- Selects only the `client` pod.
- Denies egress traffic from that pod to `1.1.1.1`.
- Leaves other traffic alone.

Now generate traffic that matches the deny rule:

```bash
kubectl -n hubble-demo exec client -- curl -m 3 -sS http://1.1.1.1
```

The command is expected to fail because Cilium is intentionally dropping the
packet. Watch the first terminal running `hubble observe`. You should see a
`DROPPED` flow with a policy-related reason, commonly similar to `Policy denied`.

The exact wording can vary by Cilium version, but the important part is that the
verdict is `DROPPED` and Hubble prints a drop reason.

## 4. Compare with a Failed Connection That May Not Be a Drop

Delete the temporary deny policy:

```bash
kubectl -n hubble-demo delete ciliumnetworkpolicy simulate-dropped-flow
```

Now run a request that commonly fails by timing out:

Open a second terminal and run:

```bash
kubectl -n hubble-demo exec client -- curl -m 3 -sS http://10.255.255.1
```

This command is expected to fail or time out.

What this command does:

- `kubectl -n hubble-demo exec client`: run a command inside the `client` pod.
- `--`: separate the `kubectl exec` options from the command that runs in the
  container.
- `curl`: create an HTTP request.
- `-m 3`: stop the request after 3 seconds.
- `-sS`: hide progress output but still show errors.
- `http://10.255.255.1`: try to reach an IP address that is commonly used for
  timeout-style tests.

The goal is not to make a successful HTTP request. The goal is to compare a
failed application request with the deterministic policy drop from the previous
step, then ask: did Cilium drop this packet too?

Watch the first terminal while the command runs. There are two important
outcomes.

If Hubble shows a `DROPPED` flow:

- Cilium made a drop decision.
- The flow line should contain a reason.
- You can use the source, destination, protocol, and reason to continue
  troubleshooting.

If Hubble shows no `DROPPED` flow:

- The `curl` command still failed.
- The failure may have been a timeout or routing issue instead of a Cilium drop.
- You need to inspect broader Hubble output before deciding what happened.

Do not assume that every failed `curl` equals a network policy problem. That is
one of the most common mistakes when debugging Kubernetes networking.

## 5. Inspect Recent Dropped Flows

If the live watch did not show anything, run a non-following query:

```bash
hubble observe -P --namespace hubble-demo --verdict DROPPED
```

This asks Hubble for recent dropped flows instead of waiting for new ones.

This is useful because you may have missed the event in the live terminal, or
the flow may have happened before you started watching. Hubble keeps a recent
flow buffer, so you can often inspect flows shortly after they occur.

If this command shows a drop, read it the same way you would read the live
output. If it still shows nothing, broaden the query.

## 6. Inspect All Client Flows

Run:

```bash
hubble observe -P --namespace hubble-demo --pod client
```

This removes the `--verdict DROPPED` filter and shows flows related to the
`client` pod.

This broader command helps answer a different question:

```text
Did the client pod send or receive any traffic that Hubble observed?
```

Possible interpretations:

- If you see client flows, Hubble is observing the pod.
- If you see `FORWARDED` flows, Cilium allowed those packets.
- If you see `DROPPED` flows, Cilium dropped those packets.
- If you see no client flows, verify that the pod exists, the command ran inside
  the pod, and Hubble is working.

You can also check that the pod exists and is ready:

```bash
kubectl -n hubble-demo get pod client -o wide
```

Remember the difference:

- `curl` output tells you whether the application request succeeded.
- Hubble output tells you what Cilium observed and decided for network packets.

Both views are useful, but they do not answer the same question.

## 7. Read a Dropped Flow

When a dropped flow appears, read it from left to right.

A flow line can vary depending on the traffic and drop reason, but the useful
shape is usually:

```text
<source> -> <destination> <protocol/port> <direction> DROPPED (<reason>)
```

Look for these fields:

- Source: the pod, workload, identity, or IP that sent the packet.
- Destination: the pod, service, identity, or IP the packet was trying to reach.
- Protocol and port: for example TCP, UDP, ICMP, port 80, or port 443.
- Direction: whether the packet is leaving or entering a workload.
- Verdict: `DROPPED` means Cilium dropped the packet.
- Reason: the explanation printed by Hubble for the drop.

Ask these questions in order:

1. Who sent the packet?
2. Where was it going?
3. Which protocol and port were involved?
4. Did Cilium drop it?
5. What reason did Hubble print?

The reason is the most important part for the next debugging step. Common drop
reasons can involve policy denial, invalid packets, service translation issues,
or other datapath decisions. The exact wording depends on the Cilium version and
the type of traffic.

## 8. Understand Common Outcomes

Use this table when comparing `curl` output with Hubble output.

| What you see | What it usually means | Next step |
| --- | --- | --- |
| `curl` times out and Hubble shows no `DROPPED` flow | The request failed, but Cilium may not have dropped it | Inspect all client flows and routing context |
| `curl` fails with a DNS error | The failure happened before reaching the intended destination | Check DNS flows and CoreDNS |
| `curl` gets connection refused | The destination was reachable enough to reject the connection | Check whether a server is listening |
| Hubble shows `FORWARDED` | Cilium allowed the packet | Look beyond Cilium policy for the failure |
| Hubble shows `DROPPED` | Cilium dropped the packet | Read the drop reason and inspect policy or datapath state |

This lab includes both outcomes:

- The `simulate-dropped-flow` policy creates a predictable Cilium drop.
- The timeout-style request may fail without producing a Cilium drop.

That comparison is the lesson. Real troubleshooting often starts with an unclear
symptom, and your job is to separate application failure from datapath drop
evidence.

## Student Check

Before moving on, make sure you can answer:

- Did Hubble show `DROPPED`, or did you only see a failed connection?
- What was the source of the traffic?
- What was the destination?
- Which protocol or port was involved?
- What reason did Hubble print?
- If there was no dropped flow, what other explanations are possible?

## Cleanup

Keep the namespace if you are continuing to the next lab.

If you are finished, remove the temporary policy and lab namespace:

```bash
kubectl -n hubble-demo delete ciliumnetworkpolicy simulate-dropped-flow --ignore-not-found
kubectl delete namespace hubble-demo
```
