# CCA Exam Preparation: Local Cilium Test Environment

This guide creates a local Kubernetes cluster for Cilium study and testing.

The environment uses:
- `kind` to run Kubernetes locally
- `kubectl` to inspect the cluster
- Cilium as the cluster CNI
- either the `cilium` CLI or Helm to install Cilium

## What You Will Build

You will create a three-node `kind` cluster:
- one control-plane node
- two worker nodes
- no default CNI

The nodes will start as `NotReady` because Kubernetes needs a CNI plugin before pod networking works. After Cilium is installed, the nodes should become `Ready`.

## Prerequisites

Make sure these tools are installed:

```bash
kind version
kubectl version --client
cilium version
helm version
```

You also need a container runtime that `kind` can use, such as Docker or Podman.

## Create The Kind Config

From this folder, create a file named `kind.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
networking:
  disableDefaultCNI: true
```

Important:
- `disableDefaultCNI: true` means `kind` will not install its normal network plugin.
- This is intentional because you will install Cilium instead.

## Create The Cluster

Run:

```bash
kind create cluster --name cilium-test --config kind.yaml
```

Check the nodes:

```bash
kubectl get nodes
```

At this point, the nodes will usually show `NotReady`.

That is expected. The cluster does not have a working CNI yet.

## Option 1: Install Cilium With The Cilium CLI

This is the simplest installation method for local study.

Preview the values Cilium will use:

```bash
cilium install --dry-run-helm-values
```

You should see values similar to:

```yaml
cluster:
  name: kind-cilium-test
ipam:
  mode: kubernetes
operator:
  replicas: 1
routingMode: tunnel
tunnelProtocol: vxlan
```

Install Cilium:

```bash
cilium install
```

Wait for Cilium to become ready:

```bash
cilium status --wait
```

Check the nodes again:

```bash
kubectl get nodes
```

The nodes should now move to `Ready`.

## Option 2: Install Cilium With Helm

Use this method when you want to practice managing Cilium as a Helm release.

Create a file named `helm-values.yaml`:

```yaml
cluster:
  name: kind-cilium-test
ipam:
  mode: kubernetes
operator:
  replicas: 1
routingMode: tunnel
tunnelProtocol: vxlan
```

Add the Cilium Helm repository:

```bash
helm repo add cilium https://helm.cilium.io
helm repo update
```

Install Cilium:

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.4 \
  --values helm-values.yaml
```

Wait for Cilium:

```bash
cilium status --wait
```

Check the nodes:

```bash
kubectl get nodes
```

## Upgrade Cilium With Helm

If you change `helm-values.yaml`, apply the change with:

```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.4 \
  --values helm-values.yaml
```

Then verify the status:

```bash
cilium status --wait
kubectl get pods -n kube-system
```

## Useful Checks

Check all Cilium pods:

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
```

Check the Cilium operator:

```bash
kubectl get pods -n kube-system -l name=cilium-operator
```

Check Cilium agent details:

```bash
cilium status
```

Run Cilium connectivity tests:

```bash
cilium connectivity test
```

The connectivity test creates temporary test workloads and verifies that pod networking works.

## Good Study Checks

After the setup is complete, verify:

1. `kubectl get nodes` shows all nodes as `Ready`
2. `cilium status --wait` completes successfully
3. Cilium pods are running in the `kube-system` namespace
4. The Cilium operator is running
5. `cilium connectivity test` passes

## Troubleshooting

If the nodes stay `NotReady`:
- Check Cilium status with `cilium status`
- Check Cilium pods with `kubectl get pods -n kube-system`
- Check Cilium pod logs with `kubectl logs -n kube-system -l k8s-app=cilium`

If Helm install fails:
- Make sure the namespace is `kube-system`
- Make sure the Helm repository was added with `helm repo add cilium https://helm.cilium.io`
- Run `helm repo update`
- Check the release with `helm status cilium -n kube-system`

If you want to start over:

```bash
kind delete cluster --name cilium-test
kind create cluster --name cilium-test --config kind.yaml
```

Then install Cilium again using either the Cilium CLI or Helm.
