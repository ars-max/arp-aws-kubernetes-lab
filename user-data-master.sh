#!/bin/bash
set -euxo pipefail

# Variables passed from Terraform
KUBERNETES_VERSION="${kubernetes_version}"
POD_CIDR="${pod_cidr}"

# Install containerd
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# --- FIX APPLIED HERE: Using cat <<EOF for robustness ---
# Get architecture and codename using shell command substitution directly
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)

# Use cat <<EOF to write the deb line, which prevents Terraform's templatefile
# from trying to interpret special characters within the string.
# Shell variables (${ARCH} and ${CODENAME}) will be expanded by the shell at runtime.
cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable
EOF
# --- END FIX ---

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

# Add Kubernetes apt repository
# KUBERNETES_VERSION is a shell variable, so just $ is needed here
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

# Install kubelet, kubeadm, kubectl
# KUBERNETES_VERSION is a shell variable, so just $ is needed here
sudo apt-get install -y kubelet="${KUBERNETES_VERSION}-*" kubeadm="${KUBERNETES_VERSION}-*" kubectl="${KUBERNETES_VERSION}-*"
sudo apt-mark hold kubelet kubeadm kubectl

# Initialize Kubernetes Master
# POD_CIDR and hostname -I are shell variables/commands, so just $ is needed here
sudo kubeadm init --pod-network-cidr=${POD_CIDR} --kubernetes-version=v${KUBERNETES_VERSION} --apiserver-advertise-address=$(hostname -I | awk '{print $1}')

# Setup kubeconfig for ubuntu user
# HOME and id -u/id -g are shell variables/commands, so just $ is needed here
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
