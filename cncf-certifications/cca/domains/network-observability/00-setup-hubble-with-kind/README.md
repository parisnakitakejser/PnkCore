# CCA Exam Preparation: Network Observability - Setup Hubble with kind

This lab sets up Cilium and Hubble, then runs one simple console check to confirm
that Hubble can see network flows. The deeper Hubble CLI exercises live in the
student lab folders.

## What You Need

- A local container runtime for kind, such as Docker or Podman
- `kind`
- `kubectl`
- The `cilium` CLI
- The `hubble` CLI

Docker, Podman, or another kind-supported container runtime must be running
before you create the cluster. This lab uses a local kind cluster only.

## 1. Create a Local kind Cluster

Install the local tools:

```bash
brew install kind kubectl
```

Create a kind cluster prepared for Cilium using the local `kind-config.yaml`
manifest in this folder:

```bash
kind create cluster --name hubble-lab --config kind-config.yaml
```

Validate that `kubectl` points at the kind cluster:

```bash
kubectl config current-context
kubectl get nodes
```

Expected context:

```text
kind-hubble-lab
```

The nodes can be `NotReady` at this point because the cluster has no CNI until
Cilium is installed.

## 2. Install the Cilium CLI

Check whether the Cilium CLI is already installed:

```bash
cilium version
```

On macOS, install or update it with Homebrew:

```bash
brew install cilium-cli
```

If you do not use Homebrew, install it manually:

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "arm64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-darwin-${CLI_ARCH}.tar.gz"{,.sha256sum}
shasum -a 256 -c "cilium-darwin-${CLI_ARCH}.tar.gz.sha256sum"
sudo tar xzvfC "cilium-darwin-${CLI_ARCH}.tar.gz" /usr/local/bin
rm "cilium-darwin-${CLI_ARCH}.tar.gz" "cilium-darwin-${CLI_ARCH}.tar.gz.sha256sum"
```

On Linux, install or update it with:

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"{,.sha256sum}
sha256sum --check "cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"
sudo tar xzvfC "cilium-linux-${CLI_ARCH}.tar.gz" /usr/local/bin
rm "cilium-linux-${CLI_ARCH}.tar.gz" "cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"
```

Validate the CLI:

```bash
cilium version
```

## 3. Install Cilium

```bash
cilium install --version 1.19.5
cilium status --wait
```

## 4. Enable Hubble

Enable Hubble and Hubble Relay:

```bash
cilium hubble enable
cilium status --wait
```

Expected result:

```text
Cilium:       OK
Operator:     OK
Hubble Relay: OK
```

Hubble Relay exposes cluster-wide flow data to the Hubble CLI. Hubble uses TCP
port `4244` between Cilium agents and Relay, so make sure this traffic is allowed
between nodes if you run in a restricted environment.

## 5. Install the Hubble CLI

Check whether `hubble` is already installed:

```bash
hubble version
```

On macOS, install or update it with Homebrew:

```bash
brew install hubble
```

If you do not use Homebrew, install it manually:

```bash
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "arm64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-darwin-${HUBBLE_ARCH}.tar.gz"{,.sha256sum}
shasum -a 256 -c "hubble-darwin-${HUBBLE_ARCH}.tar.gz.sha256sum"
sudo tar xzvfC "hubble-darwin-${HUBBLE_ARCH}.tar.gz" /usr/local/bin
rm "hubble-darwin-${HUBBLE_ARCH}.tar.gz" "hubble-darwin-${HUBBLE_ARCH}.tar.gz.sha256sum"
```

On Linux, install or update it with:

```bash
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${HUBBLE_ARCH}.tar.gz"{,.sha256sum}
sha256sum --check "hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum"
sudo tar xzvfC "hubble-linux-${HUBBLE_ARCH}.tar.gz" /usr/local/bin
rm "hubble-linux-${HUBBLE_ARCH}.tar.gz" "hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum"
```

Validate the CLI:

```bash
hubble version
```

## 6. Validate Hubble API Access

Use `-P` to let the Hubble CLI create a temporary port-forward to Hubble Relay:

```bash
hubble status -P
```

Expected result:

```text
Healthcheck (via 127.0.0.1:4245): Ok
Connected Nodes: <ready>/<total>
```

## 7. Run a Simple Hubble Smoke Test

Create a namespace with one web pod and one client pod:

```bash
kubectl create namespace hubble-demo

kubectl -n hubble-demo run web \
  --image=nginx:1.27-alpine \
  --labels=app=web \
  --port=80

kubectl -n hubble-demo run client \
  --image=curlimages/curl:8.11.1 \
  --restart=Never \
  --command -- sleep 1d

kubectl -n hubble-demo wait pod/web --for=condition=Ready --timeout=120s
kubectl -n hubble-demo wait pod/client --for=condition=Ready --timeout=120s

kubectl -n hubble-demo expose pod web --port=80 --target-port=80
```

Generate one request:

```bash
kubectl -n hubble-demo exec client -- curl -sS http://web >/dev/null
```

Confirm Hubble saw the flow:

```bash
hubble observe -P --namespace hubble-demo
```

Look for traffic from `hubble-demo/client` to `hubble-demo/web` with a
`FORWARDED` verdict. Output varies, but it should look similar to:

```text
hubble-demo/client:45678 -> hubble-demo/web:80 to-endpoint FORWARDED (TCP Flags: SYN)
hubble-demo/client:45678 <- hubble-demo/web:80 to-endpoint FORWARDED (TCP Flags: SYN, ACK)
```

If you see this, Cilium, Hubble Relay, and the Hubble CLI are working well enough
to continue with the student labs.

## 8. Clean Up

Remove the demo namespace:

```bash
kubectl delete namespace hubble-demo
```

If this was only a temporary lab and you want to disable Hubble:

```bash
cilium hubble disable
cilium status --wait
```

If you created the local kind cluster for this lab, delete it with:

```bash
kind delete cluster --name hubble-lab
```
