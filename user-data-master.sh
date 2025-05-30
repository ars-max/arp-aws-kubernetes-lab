#!/bin/bash
set -euxo pipefail

# Variables passed from Terraform
kubernetes_version="${kubernetes_version}"
pod_cidr="${pod_cidr}"
kubernetes_release_version_segment="${kubernetes_release_version_segment}"

# Install containerd
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# --- Fix for Docker repository ---
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)
cat <<EOF_DOCKER_REPO | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
deb [arch=$${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $${CODENAME} stable
EOF_DOCKER_REPO
# --- End Fix for Docker repository ---

sudo apt-get update
sudo apt-get install -y containerd.io

# Configure containerd for Kubernetes
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# --- START NEW FIXES FOR KUBEADM PREFLIGHT ERRORS ---

# Ensure br_netfilter module is loaded and persisted
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf

# Enable IP forwarding and persist it, and set bridge-nf-call-iptables
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
sudo sysctl --system # Apply sysctl changes immediately

# --- END NEW FIXES FOR KUBEADM PREFLIGHT ERRORS ---

# Add Kubernetes apt repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/${kubernetes_release_version_segment}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# --- Fix for Kubernetes repository (inside heredoc) ---
cat <<EOF_K8S_REPO | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$${kubernetes_release_version_segment}/deb/ /
EOF_K8S_REPO
# --- End Fix for Kubernetes repository ---

sudo apt-get update

# Install kubelet, kubeadm, kubectl
sudo apt-get install -y kubelet="${kubernetes_version}-*" kubeadm="${kubernetes_version}-*" kubectl="${kubernetes_version}-*"
sudo apt-mark hold kubelet kubeadm kubectl

# Initialize Kubernetes Master
sudo kubeadm init --pod-network-cidr=${pod_cidr} --kubernetes-version=v${kubernetes_version} --apiserver-advertise-address=$(hostname -I | awk '{print $1}')

# Setup kubeconfig for ubuntu user
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Install Calico CNI (or choose Flannel, etc.)
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

# Generate join command for worker nodes
kubeadm token create --print-join-command > /home/ubuntu/kubeadm_join_command.sh
chmod +x /home/ubuntu/kubeadm_join_command.sh

echo "Kubernetes master setup complete!"
