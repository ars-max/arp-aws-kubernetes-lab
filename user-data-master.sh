#!/bin/bash
set -euxo pipefail

# Variables passed from Terraform (these are directly interpolated by Terraform)
KUBERNETES_VERSION="${kubernetes_version}"
POD_CIDR="${pod_cidr}"

# K8S_RELEASE_SEGMENT is a SHELL variable whose value comes from Terraform.
# This line is fine because Terraform interpolates ${kubernetes_release_version_segment}.
# But K8S_RELEASE_SEGMENT itself is a shell variable for the rest of the script.
K8S_RELEASE_SEGMENT="${kubernetes_release_version_segment}"

# Install containerd
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# --- Fix for Docker repository ---
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)
cat <<EOF_DOCKER_REPO | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Escaped $ for ARCH and CODENAME so shell interprets them, not Terraform templatefile
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

# Add Kubernetes apt repository
# --- FIX APPLIED HERE (Line 39/40 in your output) ---
# K8S_RELEASE_SEGMENT is a shell variable, so escape the $
curl -fsSL https://pkgs.k8s.io/core:/stable:/$${K8S_RELEASE_SEGMENT}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# --- End FIX ---

# --- Fix for Kubernetes repository (inside heredoc) ---
# K8S_RELEASE_SEGMENT is a shell variable, so escape the $ here too
cat <<EOF_K8S_REPO | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$${K8S_RELEASE_SEGMENT}/deb/ /
EOF_K8S_REPO
# --- End Fix for Kubernetes repository ---

sudo apt-get update

# Install kubelet, kubeadm, kubectl
# KUBERNETES_VERSION is a direct Terraform variable, so no $$ needed here
sudo apt-get install -y kubelet="${KUBERNETES_VERSION}-*" kubeadm="${KUBERNETES_VERSION}-*" kubectl="${KUBERNETES_VERSION}-*"
sudo apt-mark hold kubelet kubeadm kubectl

# Initialize Kubernetes Master
# POD_CIDR and hostname -I are shell commands/variables, so no $$ needed for POD_CIDR.
# $(hostname -I | awk '{print $1}') is a shell command substitution, so no $$ needed.
sudo kubeadm init --pod-network-cidr=${POD_CIDR} --kubernetes-version=v${KUBERNETES_VERSION} --apiserver-advertise-address=$(hostname -I | awk '{print $1}')

# Setup kubeconfig for ubuntu user
# HOME and id -u/id -g are shell variables/commands, so no $$ needed here
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
