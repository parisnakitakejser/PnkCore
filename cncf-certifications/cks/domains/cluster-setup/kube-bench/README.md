# CKS Exam Prep: Cluster Setup - Kube-bench (CIS Benchmarks)

This guide shows how to install and run `kube-bench`, interpret results, and
start fixing common CIS benchmark findings.

References:
- https://www.cisecurity.org/cis-benchmarks
- https://github.com/aquasecurity/kube-bench
- https://aquasecurity.github.io/kube-bench/installation/

## 1) Install kube-bench

Use the installer script in this folder. Pick the correct `ARCH` for your node
(`amd64` or `arm64`).

Remote install (curl + execute):

```bash
curl -sSL https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/cks/domains/cluster-setup/kube-bench/install-kube-bench.sh | bash -s -- arm64
```

Local install:

```bash
bash install-kube-bench.sh arm64
```

Verify:

```bash
kube-bench version
```

## 2) Run the benchmarks

Full benchmark (all components):

```bash
kube-bench run --benchmark cis-1.24
```

Control plane only:

```bash
kube-bench run --benchmark cis-1.24 --targets controlplane
```

Worker node only:

```bash
kube-bench run --benchmark cis-1.24 --targets node
```

Tip: if your Kubernetes version differs, use the matching CIS benchmark (e.g.,
`cis-1.25`, `cis-1.26`).

## 3) Read the output

`kube-bench` reports each check with a status:

- `PASS` = meets the benchmark
- `FAIL` = does not meet the benchmark (action required)
- `WARN` = manual or partially automated checks

Example findings:

```
[FAIL] 1.1.12 Ensure that the etcd data directory ownership is set to etcd:etcd (Automated)
[WARN] 1.1.20 Ensure that the Kubernetes PKI certificate file permissions are set to 600 or more restrictive (Manual)
[FAIL] 4.1.1 Ensure that the kubelet service file permissions are set to 600 or more restrictive (Automated)
```

## 4) Fixing common findings (quick patterns)

Always read the specific check details in the `cfg` files under
`/etc/kube-bench/cfg` to understand the exact requirement.

Examples:

- **File ownership** issues: use `chown` (e.g., `sudo chown etcd:etcd /var/lib/etcd`)
- **File permissions** issues: use `chmod` (e.g., `sudo chmod 600 /etc/kubernetes/pki/*.crt`)
- **Service flags** issues: edit static pod manifests in `/etc/kubernetes/manifests`
  or kubelet config files and restart the relevant component

Re-run the benchmark after changes to confirm the fix.

## Exam notes

- You are usually asked to identify or fix *specific* failing checks.
- Focus on control plane vs node targets based on the task wording.
- Keep changes minimal and revertible; backup files before editing.
