# CAPA Exam Prep: Argo Rollouts - Installing Argo Rollouts

This guide covers the basic Argo Rollouts setup flow you should know for CAPA-style lab work:

- Install Argo Rollouts into a Kubernetes cluster
- Verify that the controller is running
- Install the `kubectl argo rollouts` plugin
- Open the Argo Rollouts dashboard

## What Argo Rollouts Is

Argo Rollouts is a Kubernetes controller for advanced deployment strategies.

Instead of using only the standard Kubernetes `Deployment` rolling update behavior, Argo Rollouts gives you more controlled release patterns such as:

- blue/green deployments
- canary deployments
- manual promotion steps
- rollout analysis and automated checks

This makes it useful when you want more control over how a new version reaches users.

## Why It Matters

A normal Kubernetes `Deployment` can roll out new Pods gradually, but it does not give you the same level of traffic control and staged promotion.

Argo Rollouts adds:

- better visibility into rollout state
- manual pause and promote workflows
- support for preview environments
- support for progressive delivery patterns

For CAPA-style study, the key idea is that Argo Rollouts extends Kubernetes deployment behavior without replacing Kubernetes itself.

## Prerequisites

- A working Kubernetes cluster
- `kubectl` configured for that cluster
- Optional: `brew` if you want to install the plugin with Homebrew on macOS

## 1. Install Argo Rollouts

Create the `argo-rollouts` namespace and install the official manifests:

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

This installs the Argo Rollouts controller and related resources into the `argo-rollouts` namespace.

## 2. Verify the Installation

Confirm the Pods are running:

```bash
kubectl get pods -n argo-rollouts
```

You should see the Argo Rollouts controller running in that namespace.

You can also confirm that the Rollout custom resource definitions were installed:

```bash
kubectl get crd | grep rollouts.argoproj.io
```

This is a useful verification step because Argo Rollouts works by adding custom resources to the cluster.

## 3. Install the Kubectl Plugin

On macOS with Homebrew:

```bash
brew install argoproj/tap/kubectl-argo-rollouts
```

Verify the plugin is available:

```bash
kubectl argo rollouts version
```

This plugin is commonly used for:

- checking rollout status
- promoting paused rollouts
- aborting rollouts
- opening the dashboard locally

Useful commands to remember:

```bash
kubectl argo rollouts get rollout <rollout-name>
kubectl argo rollouts promote <rollout-name>
kubectl argo rollouts abort <rollout-name>
kubectl argo rollouts retry <rollout-name>
```

## 4. Open the Dashboard

Start the Argo Rollouts dashboard with the plugin:

```bash
kubectl argo rollouts dashboard
```

By default, the dashboard is available at:

```text
http://localhost:3100/rollouts
```

Keep that command running while you use the dashboard in your browser.

## Cleanup

If you want to remove Argo Rollouts after the lab:

```bash
kubectl delete namespace argo-rollouts
```

If you only want to stop the local dashboard, just end the running dashboard command in your terminal.

## Exam Notes

- Know that Argo Rollouts is installed into its own namespace, commonly `argo-rollouts`
- Know how to install the controller manifests
- Know how to verify the controller is running
- Know that Argo Rollouts installs CRDs into the cluster
- Know that the `kubectl argo rollouts` plugin is the main CLI tool for working with rollouts
- Know that the dashboard is launched through the plugin, not by browsing directly without starting it first
- Know that blue/green and canary are two of the main rollout strategies supported by Argo Rollouts
