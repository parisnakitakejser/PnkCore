#!/usr/bin/env bash
set -euo pipefail

KUBE_VERSION="1.34.0"
KUBE_PKG_VERSION="1.34.0-1.1"

step() { echo; echo "==> $1"; }
done_step() { echo "<== $1 done"; }

### Verify Ubuntu
step "Verify Ubuntu version"
source /etc/os-release
if [[ "${VERSION_ID}" != "24.04" ]]; then
  echo "This script is for Ubuntu 24.04 only (found ${PRETTY_NAME})"
  exit 1
fi
done_step "Verify Ubuntu version"

### Architecture
step "Verify architecture"
ARCH="$(dpkg --print-architecture)"
if [[ "${ARCH}" != "amd64" && "${ARCH}" != "arm64" ]]; then
  echo "Unsupported architecture: ${ARCH}"
  exit 1
fi
done_step "Verify architecture"

### Hostname (short)
step "Set short hostname"
hostnamectl set-hostname "$(hostname | cut -d. -f1)"
done_step "Set short hostname"

### Base packages
step "Install base packages"
apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gpg \
  bash-completion \
  apt-transport-https
done_step "Install base packages"

### Disable swap
step "Disable swap"
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
systemctl mask --now swap.target
done_step "Disable swap"

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

### Install containerd
step "Install containerd"
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
done_step "Install containerd"

### Fix containerd for Kubernetes
step "Configure containerd for Kubernetes"
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i 's|sandbox_image = .*|sandbox_image = "registry.k8s.io/pause:3.10.1"|' /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd
done_step "Configure containerd for Kubernetes"

### Kubernetes repo (1.34)
step "Add Kubernetes repo"
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-1-35.gpg

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-1-35.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /
EOF
done_step "Add Kubernetes repo"

step "Install Kubernetes packages"
apt-get update
apt-get install -y \
  kubelet=${KUBE_PKG_VERSION} \
  kubeadm=${KUBE_PKG_VERSION} \
  kubectl=${KUBE_PKG_VERSION}

apt-mark hold kubelet kubeadm kubectl
done_step "Install Kubernetes packages"

### Enable kubelet
step "Enable kubelet"
systemctl enable kubelet
done_step "Enable kubelet"

### Init cluster
step "Initialize cluster"
rm -rf /etc/kubernetes /root/.kube || true

kubeadm init \
  --kubernetes-version="${KUBE_VERSION}" \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=NumCPU
done_step "Initialize cluster"

### Install K9s
step "Install K9s"
curl -sS https://webi.sh/k9s | sh; \
source ~/.config/envman/PATH.env
done_step "Install K9s"

### kubeconfig
step "Configure kubeconfig"
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
done_step "Configure kubeconfig"

### kubectl UX
step "Enable kubectl UX"
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
done_step "Enable kubectl UX"

### Allow scheduling on control-plane (lab only)
step "Allow scheduling on control-plane"
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
done_step "Allow scheduling on control-plane"

### Install Helm (stable)
step "Install Helm"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
done_step "Install Helm"

### Install Cilium (stable)
step "Install Cilium"
helm repo add cilium https://helm.cilium.io/
helm upgrade --install cilium cilium/cilium \
  --version 1.18.6 \
  --namespace kube-system
done_step "Install Cilium"

### Configure CoreDNS forwarders (lab DNS)
step "Patch CoreDNS forwarders"
python3 - <<'PY'
import subprocess

corefile = subprocess.check_output(
    ["kubectl", "-n", "kube-system", "get", "configmap", "coredns", "-o", "jsonpath={.data.Corefile}"],
    text=True,
)

old_line = "forward . /etc/resolv.conf"
new_block = "forward . 8.8.8.8 8.8.4.4"

if old_line in corefile:
    corefile = corefile.replace(old_line, new_block, 1)
elif new_block in corefile:
    print("CoreDNS forwarder already customized; skipping.")
    raise SystemExit(0)
else:
    print("CoreDNS forwarder pattern not found; skipping.")
    raise SystemExit(0)

apply = subprocess.Popen(
    [
        "kubectl",
        "-n",
        "kube-system",
        "create",
        "configmap",
        "coredns",
        f"--from-literal=Corefile={corefile}",
        "-o",
        "yaml",
        "--dry-run=client",
    ],
    stdout=subprocess.PIPE,
    text=True,
)
subprocess.run(["kubectl", "-n", "kube-system", "apply", "-f", "-"], check=True, stdin=apply.stdout, text=True)
subprocess.run(["kubectl", "-n", "kube-system", "rollout", "restart", "deployment", "coredns"], check=True)
print("CoreDNS updated and restarted.")
PY
done_step "Patch CoreDNS forwarders"

### Install Falco (stable)
step "Install Falco"
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco \
  --version 7.2.1 \
  --namespace falco  \
  --create-namespace \
  --set driver.enabled=true \
  --set driver.kind=modern_ebpf \
  --set containerSecurityContext.privileged=true
done_step "Install Falco"

## Install Go (latest) + BOM
step "Install Go + BOM"
sudo add-apt-repository -y ppa:longsleep/golang-backports
sudo apt update -y
sudo apt install golang-go -y

go install sigs.k8s.io/bom/cmd/bom@latest
install -m 0755 /root/go/bin/bom /usr/local/bin/bom
done_step "Install Go + BOM"

### Done
echo
echo "✅ Kubernetes ${KUBE_VERSION} is ready"
echo
echo "### Join command ###"
kubeadm token create --print-join-command --ttl 0
