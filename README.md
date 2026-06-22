# Simple Kubernetes Cluster with Multipass

A lightweight Kubernetes lab environment built with **Multipass**, **kubeadm**, and **containerd**.

This project provides a simple and reproducible way to deploy a Kubernetes cluster using Ubuntu virtual machines managed by Multipass. It is ideal for Kubernetes learning, CKA/CKS exam preparation, testing workloads, and experimenting with cluster administration in a local environment.

The setup is optimized for both **ARM64** (Apple Silicon M1/M2/M3 and ARM-based Linux hosts) and **x86_64** systems.

---

# Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
  - [Host Requirements](#host-requirements)
  - [Verify Multipass Installation](#verify-multipass-installation)
- [Quick Start](#quick-start)
  - [1. Create the Virtual Machines](#1-create-the-virtual-machines)
  - [2. Copy the Installation Scripts](#2-copy-the-installation-scripts)
  - [3. Install the Control Plane](#3-install-the-control-plane)
  - [4. Join the Worker Node](#4-join-the-worker-node)
  - [5. Verify the Cluster](#5-verify-the-cluster)
- [Usage](#usage)
  - [Show Cluster Nodes](#show-cluster-nodes)
  - [Show Cluster Pods](#show-cluster-pods)
  - [Deploy a Test Application](#deploy-a-test-application)
  - [Scale a Deployment](#scale-a-deployment)
  - [Delete a Deployment](#delete-a-deployment)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [License](#license)

---

# Architecture

The cluster consists of one Kubernetes control plane node and one worker node running inside Ubuntu virtual machines managed by Multipass.

```text
+--------------------------------------------------+
|                   Host System                    |
|               macOS / Linux Host                 |
|                    Multipass                     |
+--------------------------+-----------------------+
                           |
        +------------------+------------------+
        |                                     |
+-------+--------+                   +--------+-------+
|   cks-master   |                   |   cks-worker   |
| Control Plane  |                   |     Worker     |
+----------------+                   +----------------+
| kube-apiserver |                   | kubelet        |
| kube-scheduler |                   | kube-proxy     |
| controller-mgr |                   | containerd     |
| etcd           |                   |                |
| kubelet        |                   |                |
| containerd     |                   |                |
+----------------+                   +----------------+
```

## Components

| Component | Purpose |
|-----------|---------|
| Multipass | Virtual machine management |
| Ubuntu 26.04 LTS | Operating system |
| containerd | Container runtime |
| kubeadm | Kubernetes cluster bootstrap |
| kubelet | Node agent |
| kubectl | Kubernetes command-line tool |
| Flannel | Container network interface (CNI) |

---

# Prerequisites

## Host Requirements

### macOS

- Apple Silicon (M1/M2/M3) or Intel
- Multipass installed

### Linux

- Ubuntu 22.04 or newer
- Multipass installed

### Recommended Resources

| Resource | Master | Worker |
|-----------|---------|---------|
| CPU | 2 vCPUs | 2 vCPUs |
| Memory | 4 GB | 4 GB |
| Disk | 20 GB | 20 GB |

---

## Verify Multipass Installation

```bash
multipass version
```

Expected output:

```text
multipass   x.x.x
multipassd  x.x.x
```

---

# Quick Start

## 1. Create the Virtual Machines

Create the control plane node:

```bash
multipass launch 26.04 \
  --name cks-master \
  --cpus 2 \
  --memory 4G \
  --disk 20G
```

Create the worker node:

```bash
multipass launch 26.04 \
  --name cks-worker \
  --cpus 2 \
  --memory 4G \
  --disk 20G
```

---

## 2. Copy the Installation Scripts

Copy the master installation script:

```bash
multipass transfer cks-master/install-all.sh \
  cks-master:/home/ubuntu/install-all.sh
```

Copy the worker installation script:

```bash
multipass transfer cks-worker/install-all.sh \
  cks-worker:/home/ubuntu/worker-install-all.sh
```

---

## 3. Install the Control Plane

Connect to the master node:

```bash
multipass shell cks-master
```

Run the installation:

```bash
chmod +x install-all.sh
sudo ./install-all.sh
```

The script will:

- Configure kernel modules
- Configure sysctl settings
- Disable swap
- Install containerd
- Install Kubernetes components
- Initialize the cluster using kubeadm
- Install Flannel networking
- Generate a worker join command

At the end of the installation you will receive a command similar to:

```bash
kubeadm join <MASTER-IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

Save this command for the next step.

---

## 4. Join the Worker Node

Connect to the worker:

```bash
multipass shell cks-worker
```

Run:

```bash
chmod +x worker-install-all.sh

sudo ./worker-install-all.sh \
'kubeadm join <MASTER-IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>'
```

Wait until the worker successfully joins the cluster.

---

## 5. Verify the Cluster

Return to the master node and verify:

```bash
kubectl get nodes
```

Expected output:

```text
NAME         STATUS   ROLES           VERSION
cks-master   Ready    control-plane   v1.34.x
cks-worker   Ready    <none>          v1.34.x
```

Check system pods:

```bash
kubectl get pods -A
```

All pods should eventually reach the `Running` state.

---

# Usage

## Show Cluster Nodes

```bash
kubectl get nodes -o wide
```

---

## Show Cluster Pods

```bash
kubectl get pods -A
```

---

## Deploy a Test Application

Create a simple NGINX deployment:

```bash
kubectl create deployment nginx \
  --image=nginx
```

Verify:

```bash
kubectl get deployments
kubectl get pods
```

---

## Scale a Deployment

Scale NGINX to three replicas:

```bash
kubectl scale deployment nginx \
  --replicas=3
```

Verify:

```bash
kubectl get pods -o wide
```

---

## Delete a Deployment

```bash
kubectl delete deployment nginx
```

---

# Project Structure

```text
simple-multipass-kubernetes-with-multipass/
│
├── cks-master/
│   └── install-all.sh
│
├── cks-worker/
│   └── install-all.sh
│
└── README.md
```

---

# Troubleshooting

## Node Shows NotReady

Check node status:

```bash
kubectl get nodes
```

Inspect the node:

```bash
kubectl describe node <node-name>
```

---

## CoreDNS Remains Pending

Common causes:

- Insufficient disk space
- Insufficient memory
- Node taints
- Network plugin issues

Verify:

```bash
kubectl get pods -A
kubectl describe pod -n kube-system <pod-name>
```

---

## Verify Flannel

```bash
kubectl get pods -n kube-flannel
```

Expected:

```text
NAME                    READY   STATUS
kube-flannel-ds-xxxxx   1/1     Running
```

---

# Cleanup

Delete all virtual machines:

```bash
multipass delete cks-master cks-worker
multipass purge
```

Verify cleanup:

```bash
multipass list
```

---

# License

This project is licensed under the MIT License.