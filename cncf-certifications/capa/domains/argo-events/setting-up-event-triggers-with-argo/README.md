# CAPA Exam Prep: Argo Events - Setting Up Event Triggers with Argo

This guide covers the basic Argo Events trigger flow you should know for CAPA-style lab work:

- Install Argo Events into a Kubernetes cluster
- Create an EventBus
- Deploy a webhook EventSource
- Deploy the required RBAC
- Create a Sensor that reacts to the webhook event
- Trigger the flow with `curl`

## Prerequisites

- A working Kubernetes cluster
- `kubectl` configured for that cluster
- Argo Workflows already installed
- `curl` available locally for testing

Argo Events is commonly used together with Argo Workflows, because sensors often trigger workflows when an event is received.

## 1. Install Argo Events

Create the `argo-events` namespace and install Argo Events:

```bash
kubectl create namespace argo-events
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
```

Confirm the Pods are running:

```bash
kubectl get pods -n argo-events
```

## 2. Create an EventBus

Argo Events needs an EventBus for event transport between sources and sensors.

Apply the example native EventBus:

```bash
kubectl apply -n argo-events -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-events/setting-up-event-triggers-with-argo/eventbus-native.yaml
```

This gives the EventSource and Sensor a messaging layer they can use to communicate.

## 3. Create a Webhook EventSource

Deploy the example webhook EventSource:

```bash
kubectl apply -n argo-events -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-events/setting-up-event-triggers-with-argo/eventsource-webhook.yaml
```

This creates an HTTP endpoint that Argo Events can listen on.

## 4. Apply Sensor and Workflow RBAC

The sensor needs permission to watch events and trigger workflows.

Apply the example RBAC manifests:

```bash
kubectl apply -n argo-events -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-events/setting-up-event-triggers-with-argo/sensor-rbac.yaml
kubectl apply -n argo-events -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-events/setting-up-event-triggers-with-argo/workflow-rbac.yaml
```

## 5. Create the Webhook Sensor

Deploy the example sensor:

```bash
kubectl apply -n argo-events -f https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/capa/domains/argo-events/setting-up-event-triggers-with-argo/sensor-webhook.yaml
```

The sensor waits for events from the webhook EventSource and reacts when one arrives.

## 6. Expose the Webhook EventSource

Port-forward the EventSource service locally:

```bash
kubectl -n argo-events port-forward svc/webhook-eventsource-svc 12000:12000
```

This makes the webhook available at:

```text
http://localhost:12000/example
```

## 7. Send a Test Event

Send a webhook request with `curl`:

```bash
curl -d '{"message":"this is my first webhook"}' \
  -H "Content-Type: application/json" \
  -X POST \
  http://localhost:12000/example
```

If everything is configured correctly, the EventSource receives the webhook, the Sensor processes the event, and the configured trigger action runs.

## 8. Inspect the Result

Check the Argo Events resources:

```bash
kubectl get eventbus -n argo-events
kubectl get eventsource -n argo-events
kubectl get sensor -n argo-events
kubectl get pods -n argo-events
```

If the sensor is configured to trigger a workflow, you can also inspect workflows in the Argo namespace:

```bash
kubectl get workflows -n argo
argo list -n argo
```

## Exam Notes

- Know that Argo Events usually works together with Argo Workflows
- Know the role of the EventBus, EventSource, and Sensor
- Know that a webhook EventSource can be tested locally with `kubectl port-forward`
- Know that RBAC is required for sensors that trigger workflows
- Know that the typical event flow is `EventSource receives event -> Sensor reacts -> Trigger executes`

## Cleanup

When you are done with the lab, you can remove the example resources:

```bash
kubectl delete -n argo-events -f sensor-webhook.yaml
kubectl delete -n argo-events -f eventsource-webhook.yaml
kubectl delete -n argo-events -f eventbus-native.yaml
kubectl delete -n argo-events -f sensor-rbac.yaml
kubectl delete -n argo-events -f workflow-rbac.yaml
```

If you want to remove the full Argo Events installation too:

```bash
kubectl delete namespace argo-events
```
