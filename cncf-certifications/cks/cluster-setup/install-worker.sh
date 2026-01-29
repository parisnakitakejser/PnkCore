#!/usr/bin/env bash
set -euo pipefail

KUBE_VERSION="1.34.0"
KUBE_PKG_VERSION="1.34.0-1.1"
PAUSE_IMAGE="registry.k8s.io/pause:3.10.1"

step() { echo; echo "==> $1"; }
done_step() { echo "<== $1 done"; }

### Verify Ubuntu
step "Verify Ubuntu version"
source /etc/os-release
if [[ "${VERSION_ID}" != "24.04" ]]; then
  echo "#################################"
  echo "############ WARNING ############"
  echo "#################################"
  echo
  echo "This script is intended for Ubuntu 24.04."
  echo "You're using: ${PRETTY_NAME}"
  echo "Abort with Ctrl+C or press Enter to continue."
  read -r
fi
done_step "Verify Ubuntu version"

### Architecture sanity
step "Verify architecture"
ARCH="$(dpkg --print-architecture)"
if [[ "${ARCH}" != "amd64" && "${ARCH}" != "arm64" ]]; then
  echo "Unsupported architecture: ${ARCH} (need amd64 or arm64)"
  exit 1
fi
done_step "Verify architecture"

### Set short hostname
step "Set short hostname"
hostnamectl set-hostname "$(hostname | cut -d. -f1)"
done_step "Set short hostname"

### Disable swap
step "Disable swap"
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
systemctl mask --now swap.target
done_step "Disable swap"

### Base packages
step "Install base packages"
apt-get update
apt-get install -y ca-certificates curl gpg bash-completion apt-transport-https
done_step "Install base packages"

### Cleanup old kubeadm state (safe for lab workers)
step "Cleanup old kubeadm state"
kubeadm reset -f || true
rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet/pki || true
rm -rf /etc/cni /opt/cni /var/lib/cni || true
done_step "Cleanup old kubeadm state"

### Kernel modules
step "Load kernel modules"
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
done_step "Load kernel modules"

### Sysctl
step "Apply sysctl settings"
cat <<EOF >/etc/sysctl.d/99-kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system
done_step "Apply sysctl settings"

### Install containerd (Ubuntu repo)
step "Install containerd"
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
done_step "Install containerd"

### Configure containerd for Kubernetes
# - systemd cgroups
# - pause image matches kubeadm recommendation for 1.34
step "Configure containerd for Kubernetes"
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i "s|sandbox_image = \".*\"|sandbox_image = \"${PAUSE_IMAGE}\"|" /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd
done_step "Configure containerd for Kubernetes"

### Kubernetes repo (1.34)
step "Add Kubernetes repo"
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-1-35.gpg

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-1-35.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /
EOF
done_step "Add Kubernetes repo"

step "Install Kubernetes packages"
apt-get update
apt-get install -y \
  kubelet="${KUBE_PKG_VERSION}" \
  kubeadm="${KUBE_PKG_VERSION}" \
  kubectl="${KUBE_PKG_VERSION}"

apt-mark hold kubelet kubeadm kubectl
done_step "Install Kubernetes packages"

### crictl config (optional but handy)
step "Configure crictl"
cat <<EOF >/etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF
done_step "Configure crictl"

### Start kubelet
step "Start kubelet"
systemctl enable kubelet
systemctl restart kubelet
done_step "Start kubelet"

echo
echo "✅ Worker prerequisites installed for Kubernetes ${KUBE_VERSION}"
echo
echo "Next step:"
echo "1) On the control-plane, run:"
echo "   kubeadm token create --print-join-command --ttl 0"
echo
echo "2) Copy/paste the join command here on this worker (run as root)."
echo
