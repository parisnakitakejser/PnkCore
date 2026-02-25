#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "" ]]; then
  echo "Usage: $0 <amd64|arm64>" >&2
  exit 1
fi

ARCH="$1"
if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
  echo "Unsupported ARCH: $ARCH (use amd64 or arm64)" >&2
  exit 1
fi

VER=$(curl -s https://api.github.com/repos/aquasecurity/kube-bench/releases/latest \
  | grep tag_name \
  | cut -d '"' -f4 \
  | sed 's/v//')

cd /tmp
curl -LO "https://github.com/aquasecurity/kube-bench/releases/download/v${VER}/kube-bench_${VER}_linux_${ARCH}.tar.gz"
tar -xzf "kube-bench_${VER}_linux_${ARCH}.tar.gz"

sudo install -m 0755 kube-bench /usr/local/bin/kube-bench
sudo mkdir -p /etc/kube-bench
sudo cp -r cfg /etc/kube-bench/
