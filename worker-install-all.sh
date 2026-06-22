#!/usr/bin/env bash
set -euo pipefail

K8S_VERSION="${K8S_VERSION:-v1.34}"

if [[ $# -lt 1 ]]; then
  echo "Usage:"
  echo "  sudo ./install-all.sh '<kubeadm join ...>'"
  exit 1
fi

JOIN_COMMAND="$1"

echo "[1/6] System vorbereiten"
apt-get update
apt-get install -y curl ca-certificates gpg apt-transport-https

echo "[2/6] Kernel Module + sysctl"

cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

echo "[3/6] Swap deaktivieren"
swapoff -a
sed -i.bak '/ swap / s/^/#/' /etc/fstab || true

echo "[4/6] containerd installieren"
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml

sed -i \
  's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd

echo "[5/6] Kubernetes Repository + Pakete"

mkdir -p /etc/apt/keyrings

curl -fsSL \
  "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /
EOF

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

echo "[6/6] Worker dem Cluster hinzufügen"
eval "${JOIN_COMMAND}"

echo
echo "Worker joined."