#!/usr/bin/env bash
set -euo pipefail

K8S_VERSION="${K8S_VERSION:-v1.34}"
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"

echo "[1/7] System vorbereiten"
apt-get update
apt-get install -y curl ca-certificates gpg apt-transport-https

echo "[2/7] Kernel Module + sysctl"

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

echo "[3/7] Swap deaktivieren"

swapoff -a
sed -i.bak '/ swap / s/^/#/' /etc/fstab || true

echo "[4/7] containerd installieren"

apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml

sed -i \
  's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd

echo "[5/7] Kubernetes Repository"

mkdir -p /etc/apt/keyrings

curl -fsSL \
  "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /
EOF

apt-get update

echo "[6/7] kubeadm kubelet kubectl"

apt-get install -y kubelet kubeadm kubectl

apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

echo "[7/7] Cluster initialisieren"

kubeadm init --pod-network-cidr="${POD_CIDR}"

echo "Kubeconfig einrichten"

mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

mkdir -p /home/ubuntu/.kube
cp -f /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "Warte auf API Server..."
sleep 15

echo "Flannel installieren"

kubectl apply -f \
https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo "Control Plane taint entfernen"

kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

echo
echo "Join Command:"
kubeadm token create --print-join-command

echo
echo "Nodes:"
kubectl get nodes -o wide

echo
echo "Pods:"
kubectl get pods -A