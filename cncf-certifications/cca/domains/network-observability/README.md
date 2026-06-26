# Network Observability with Hubble

This directory contains a step-by-step Hubble CLI learning path. Start with the
kind setup lab, then continue through the focused Hubble CLI exercises.

## Labs

0. [Setup Hubble with kind](00-setup-hubble-with-kind/README.md)

   Set up the local kind cluster, install Cilium, enable Hubble, install the
   Hubble CLI, and run a smoke test. Students should complete this first because
   the later labs depend on a working Hubble environment.

1. [Observing Pod-to-Pod Traffic](01-observing-pod-to-pod-traffic/README.md)

   Create a simple client and web pod, generate traffic between them, and use
   Hubble to identify source pods, destination pods, destination ports, TCP
   flags, and `FORWARDED` verdicts.

2. [DNS Visibility](02-dns-visibility/README.md)

   Watch DNS lookups from a pod to CoreDNS, compare failed and successful name
   resolution, and learn how DNS traffic appears in Hubble when debugging
   service connectivity.

3. [Debugging Dropped Flows](03-debugging-dropped-flows/README.md)

   Generate traffic that Cilium intentionally drops, filter Hubble output for
   `DROPPED` flows, and practice separating a true Cilium drop from other
   connection failures such as DNS errors or refused connections.

4. [Network Policy Observability](04-network-policy-observability/README.md)

   Apply a Cilium deny policy to a client-to-web path, then use Hubble verdicts
   and flow fields to prove how the policy changed the data path from allowed to
   denied traffic.

5. [Service and Load-Balancing Flows](05-service-and-load-balancing-flows/README.md)

   Send traffic through a Kubernetes Service with multiple backend pods and use
   Hubble to connect the stable Service name with the backend pod that actually
   receives each request.

6. [HTTP L7 Visibility](06-http-l7-visibility/README.md)

   Enable Layer 7 HTTP visibility with a `CiliumNetworkPolicy` and observe HTTP
   method, path, response code, source pod, destination pod, and policy verdict
   in Hubble.

7. [Live Debugging with `--follow`](07-live-debugging-with-follow/README.md)

   Keep `hubble observe --follow` running while requests are generated, then
   narrow the live stream with namespace, pod, and verdict filters to practice a
   real-time troubleshooting workflow.

8. [Filtering and Output Formats](08-filtering-and-output-formats/README.md)

   Start with broad Hubble output, then combine filters for namespace, pod,
   direction, verdict, protocol, and port. Use JSON output when compact text
   output hides fields needed for troubleshooting.

9. [Troubleshooting Hubble Itself](09-troubleshooting-hubble-itself/README.md)

   Troubleshoot the observability system from the outside inward: Hubble CLI,
   Hubble Relay, Cilium agents, and finally workload traffic. This helps
   students distinguish Hubble access problems from application traffic
   problems.

## Start Here

Begin with [Setup Hubble with kind](00-setup-hubble-with-kind/README.md). It
creates the local kind cluster, installs Cilium, enables Hubble, installs the
Hubble CLI, and runs one simple smoke test to confirm Hubble is working.
