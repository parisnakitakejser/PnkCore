# CKS Exam Preparation: Cluster Setup

This folder contains simple scripts to build a small Kubernetes lab cluster
for CKS study and hands-on practice.

## Recommended environment

- 3 VMs
- 2 vCPU, 4 GB RAM, 50 GB disk each
- Ubuntu Server 24.04 (kernel 6.8)
- Falco 0.38+

## VM naming

Use these names to match the scripts and examples:

- VM 1: `cks-main`
- VM 2: `cks-worker1`
- VM 3: `cks-worker2`

## What is in this folder

- `install-main.sh` sets up the control plane node and installs Cilium & Falco
- `install-worker.sh` sets up worker nodes

## Preinstalled tools (CKS focus)

These are preinstalled to match common CKS objectives:

- BOM / SBOM tooling
- Cilium (CNI)
- Falco (runtime security)

## Quick start

1) Log in to each VM and become root:

```bash
sudo -i
```

2) On the control plane VM (`cks-main`), run:

```bash
curl -fsSL https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/cks/cluster-setup/install-main.sh | bash
```

3) On each worker VM (`cks-worker1`, `cks-worker2`), run:

```bash
curl -fsSL https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/cks/cluster-setup/install-worker.sh | bash
```

## Notes and tips

- Keep a copy of the join command/token from the control plane output.
- If a script fails, re-run it after fixing the error (idempotent is best,
  but not guaranteed).
- This lab is for study. Do not use in production.
- If a VM has multiple NICs or more than one IP address, kubelet may pick the
  wrong node IP. In that case, set the node IP explicitly on **each node**
  that has multiple NICs or ambiguous IPs, then restart kubelet:

```bash
echo 'KUBELET_EXTRA_ARGS=--node-ip=192.168.190.137' > /etc/default/kubelet
systemctl restart kubelet
```

Tip: find the correct IP with `ip -4 addr show` and use the VM's primary
interface address.

## Troubleshooting

- Verify VM time is correct and NTP is enabled.
- Check that your VMs can reach each other on the network.
- Ensure you run scripts as root.
