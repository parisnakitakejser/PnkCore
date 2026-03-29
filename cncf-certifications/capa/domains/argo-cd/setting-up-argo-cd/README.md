# CAPA Exam Prep: Setting Up Argo CD

This guide covers the basic Argo CD setup flow you are expected to understand for CAPA-style lab work:

- Install Argo CD into a Kubernetes cluster
- Access the Argo CD API server and web UI
- Retrieve the initial admin password
- Log in with the Argo CD CLI
- Change the default password

## Prerequisites

- A working Kubernetes cluster
- `kubectl` configured for that cluster
- DNS enabled in the cluster
- Optional: `brew` if you want to install the CLI with Homebrew on macOS

## 1. Install Argo CD

Create the `argocd` namespace and install the official Argo CD manifests:

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

This installs the core Argo CD components into the `argocd` namespace.

## 2. Access the Argo CD API Server

For local testing, the simplest option is port-forwarding:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

You can then open the web UI at:

```text
https://localhost:8080
```

Because the default install uses a self-signed certificate, your browser may warn you before opening the UI.

## 3. Get the Initial Admin Password

Argo CD creates an initial admin password and stores it in a Kubernetes secret:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

You can use this password to sign in to the web UI with:

```text
username: admin
password: <decoded password>
```

## 4. Install the Argo CD CLI

On macOS with Homebrew:

```bash
brew install argocd
```

Other installation methods are available in the official CLI install docs.

## 5. Log In with the CLI

You can retrieve the same initial password directly with the CLI:

```bash
argocd admin initial-password -n argocd
```

Then log in to the API server:

```bash
argocd login localhost:8080 --insecure
```

`--insecure` is commonly needed for local labs because the default installation uses a self-signed certificate.

If you are not keeping the port-forward session open, use the actual Argo CD server address instead of `localhost:8080`.

## 6. Change the Default Password

After logging in, change the admin password:

```bash
argocd account update-password
```

Example:

```text
Current password: <initial-admin-password>
New password: SuperSecret1234
Confirm new password: SuperSecret1234
```

This is standard post-install hygiene and avoids continuing to use the bootstrap credential.

## Exam Notes

- Know that Argo CD is typically installed into its own namespace, usually `argocd`
- Know how to expose the API server temporarily with `kubectl port-forward`
- Know where the initial admin password is stored
- Know the difference between browser login and CLI login
- Expect self-signed TLS in lab environments

## References

- Official getting started guide: https://argo-cd.readthedocs.io/en/latest/getting_started/
- Official releases page: https://github.com/argoproj/argo-cd/releases/latest
