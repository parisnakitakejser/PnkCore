# CAPA Exam Prep: Argo Workflows - Setting Up Argo Workflows

This guide covers the basic Argo Workflows setup flow you should know for CAPA-style lab work:

- Install Argo Workflows into a Kubernetes cluster
- Configure the Argo Server auth mode for local lab access
- Open the Argo Workflows UI
- Install and verify the Argo CLI
- Use a few core commands you are likely to need in exercises

## Prerequisites

- A working Kubernetes cluster
- `kubectl` configured for that cluster
- Internet access from the cluster or local machine to pull the install manifest
- Optional: `brew` if you want to install the CLI with Homebrew on macOS

## 1. Install Argo Workflows

Create the `argo` namespace and apply the official install manifest:

```bash
kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.7.3/install.yaml
```

This installs the Argo Workflows controllers, server, and supporting resources into the `argo` namespace.

## 2. Configure Argo Server Auth Mode

For local study environments, it is common to run the Argo Server in `server` auth mode:

```bash
kubectl patch deployment argo-server \
  -n argo \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["server","--auth-mode=server"]}]'
```

This updates the `argo-server` Deployment so the web UI is easier to access in a lab environment.

## 3. Open the Web UI

Port-forward the Argo Server service:

```bash
kubectl -n argo port-forward svc/argo-server 2746:2746
```

Then open:

```text
https://localhost:2746
```

Depending on your browser and cluster setup, you may see a TLS warning for the local connection.

## 4. Install the Argo CLI

On macOS with Homebrew:

```bash
brew install argo
```

If you are not using macOS, install the CLI from the official releases page:

https://github.com/argoproj/argo-workflows/releases/

## 5. Verify the CLI

Check that the CLI is installed:

```bash
argo version
```

Example output:

```text
argo: v4.0.4+fe0af11.dirty
  BuildDate: 2026-04-02T14:23:38Z
  GitCommit: fe0af119897a54f4c7db117a5912a5559c46532f
  GitTreeState: dirty
  GitTag: v4.0.4
  GoVersion: go1.26.1
  Compiler: gc
  Platform: darwin/arm64
```

Your exact version output may differ depending on when you install the CLI.

## 6. Useful Argo CLI Commands

These are good commands to know for labs and demos:

```bash
argo list
argo get <workflow-name>
argo submit <workflow-file.yaml>
argo watch <workflow-name>
argo template list
argo logs <workflow-name>
```

What they do:

- `argo list` lists workflows
- `argo get <workflow-name>` shows details for one workflow
- `argo submit <workflow-file.yaml>` submits a workflow from a YAML file
- `argo watch <workflow-name>` streams workflow progress
- `argo template list` lists workflow templates
- `argo logs <workflow-name>` shows logs for workflow pods

## Exam Notes

- Know that Argo Workflows is commonly installed into its own namespace, often `argo`
- Know how to expose the UI temporarily with `kubectl port-forward`
- Know how to switch Argo Server to `--auth-mode=server` in a lab setup
- Know the difference between installing the platform and installing the CLI
- Expect version output to vary between environments
