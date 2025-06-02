#!/bin/bash
set -euxo pipefail

# --- Variables passed from Terraform ---
# Ensure these variables are correctly passed from your Terraform configuration
kubernetes_version="${kubernetes_version}"
pod_cidr="${pod_cidr}"
# This variable might be like "v1.29" if your KUBERNETES_VERSION is "1.29.0"
kubernetes_release_version_segment="${kubernetes_release_version_segment}" 

# --- Update apt and Install containerd ---
echo "--- Updating apt and installing containerd ---"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key and repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Define architecture and codename explicitly for the deb line
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)
cat <<EOF_DOCKER_REPO | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
deb [arch=$${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $${CODENAME} stable
EOF_DOCKER_REPO

sudo apt-get update
sudo apt-get install -y containerd.io

# Configure containerd for Kubernetes
echo "--- Configuring containerd for Kubernetes ---"
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# --- Disable Swap ---
echo "--- Disabling swap ---"
sudo swapoff -a
# Remove swap entry from /etc/fstab to persist disable across reboots
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# --- Configure Kernel Modules and Sysctl parameters for Kubernetes networking ---
echo "--- Configuring kernel modules and sysctl parameters ---"
cat <<EOF_KERNEL_MODULES | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF_KERNEL_MODULES

sudo modprobe overlay
sudo modprobe br_netfilter # Ensure this module is loaded immediately

cat <<EOF_SYSCTL | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF_SYSCTL

sudo sysctl --system # Apply sysctl changes immediately

# --- Add Kubernetes apt repository ---
echo "--- Adding Kubernetes apt repository ---"
curl -fsSL https://pkgs.k8s.io/core:/stable:/$${kubernetes_release_version_segment}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes apt repository to sources.list
cat <<EOF_K8S_REPO | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$${kubernetes_release_version_segment}/deb/ /
EOF_K8S_REPO

sudo apt-get update

# --- Install kubelet, kubeadm, kubectl ---
echo "--- Installing kubelet, kubeadm, kubectl ---"
# Version pinning using wildcards for patch version, ensuring exact minor version
sudo apt-get install -y kubelet="${kubernetes_version}-*" kubeadm="${kubernetes_version}-*" kubectl="${kubernetes_version}-*"
sudo apt-mark hold kubelet kubeadm kubectl

# Ensure kubelet cgroup driver is systemd (often redundant with containerd config, but good to be explicit)
echo "--- Ensuring kubelet cgroup driver is systemd ---"
sudo mkdir -p /etc/systemd/system/kubelet.service.d
echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' | sudo tee /etc/default/kubelet

sudo systemctl daemon-reload
sudo systemctl enable kubelet --now # Ensure kubelet is enabled and running

# --- Initialize Kubernetes Master ---
echo "--- Initializing Kubernetes Master ---"
# Using 'hostname -I | awk '{print $1}'' to get the primary IP of the instance
sudo kubeadm init --pod-network-cidr=${pod_cidr} --kubernetes-version=v${kubernetes_version} --apiserver-advertise-address=$(hostname -I | awk '{print $1}')

# --- Setup kubeconfig for 'ubuntu' user ---
echo "--- Setting up kubeconfig for ubuntu user ---"
# Explicitly use /home/ubuntu instead of $HOME, and set correct ownership
sudo mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config # Correct ownership for ubuntu user

# --- Install Calico CNI (or choose Flannel, etc.) ---
echo "--- Installing Calico CNI ---"
# Ensure these URLs are correct for your chosen Calico version and Kubernetes version
# Check https://docs.projectcalico.org/ for the latest compatible manifests
kubectl --kubeconfig=/home/ubuntu/.kube/config create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
kubectl --kubeconfig=/home/ubuntu/.kube/config create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

# Wait for Calico to be ready before generating join command (optional, but safer)
echo "--- Waiting for Calico pods to be ready (up to 5 minutes) ---"
# This loop waits for the 'calico-node' daemonset to be ready, indicating CNI is functional
# Note: --kubeconfig is used here to ensure kubectl uses the correct config
timeout 300 bash -c \
'until kubectl --kubeconfig=/home/ubuntu/.kube/config get pods -A -o wide | grep -q "calico-node.*Running"; do \
  echo "Waiting for Calico pods to be running..."; \
  sleep 10; \
done' || echo "Timeout waiting for Calico pods. Proceeding anyway."

# --- Generate join command for worker nodes ---
echo "--- Generating kubeadm join command ---"
# Use sudo tee to ensure write permissions and direct to /home/ubuntu explicitly
# The `sudo` in the output will be stripped by Terraform's `replace` function for worker user_data
kubeadm token create --print-join-command | sudo tee /home/ubuntu/kubeadm_join_command.sh > /dev/null
sudo chmod +x /home/ubuntu/kubeadm_join_command.sh

echo "Kubernetes master setup complete!"
echo "The kubeadm join command is available at /home/ubuntu/kubeadm_join_command.sh"
