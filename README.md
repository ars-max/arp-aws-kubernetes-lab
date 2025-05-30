# arp-aws-kubernetes-lab
my Kubernetes lab setup on AWS using Terraform and GitHub Actions.


to connect to worker node from master node
1 - copy the key file from local system to master node
ssh -i "C:\Users\YourUserName\.ssh\my-kubeadm-lab-key.pem" ubuntu@3.81.235.147

2- # On the master node:
chmod 400 ~/my-kubeadm-lab-key.pem

3- # On the master node:
ssh -i ~/my-kubeadm-lab-key.pem ubuntu@10.0.2.232

4- Once you're on the worker node, you can:

Check cloud-init-output.log: This is the most important log for debugging your user_data script on the worker.
Bash

tail -f /var/log/cloud-init-output.log
Check kubelet status:
Bash

sudo systemctl status kubelet
Check Docker/containerd status:
Bash


Outputs:
kubeconfig_instructions = <<EOT
To get your kubeconfig file:
1. SSH into the master node: 44.204.39.53
2. Run: sudo cat /etc/kubernetes/admin.conf > kubeconfig

   ubuntu@ip-10-0-101-197:/etc/kubernetes$ cd ..
ubuntu@ip-10-0-101-197:/etc$ ls -ltr | grep -i kubernetes/
ubuntu@ip-10-0-101-197:/etc$ sudo chown ubuntu:ubuntu kubernetes/
ubuntu@ip-10-0-101-197:/etc$ cd kubernetes/
ubuntu@ip-10-0-101-197:/etc/kubernetes$ ls -ltr
total 36
drwxr-xr-x 3 root root 4096 May 30 05:58 pki
-rwxrwxrwx 1 root root 5648 May 30 05:58 admin.conf
-rw------- 1 root root 5676 May 30 05:58 controller-manager.conf
-rw------- 1 root root 5624 May 30 05:58 scheduler.conf
drwxrwxr-x 2 root root 4096 May 30 05:58 manifests
-rw------- 1 root root 2004 May 30 05:58 kubelet.conf
ubuntu@ip-10-0-101-197:/etc/kubernetes$ sudo cat /etc/kubernetes/admin.conf > kubeconfig



4. Copy 'kubeconfig' file to your local machine: scp -i ~/.ssh/my-kubeadm-lab-key.pem ubuntu@44.204.39.53:~/kubeconfig .
5. Set KUBECONFIG environment variable: export KUBECONFIG=./kubeconfig
6. Test with: kubectl get nodes
EOT
master_private_ip = "10.0.101.197"
master_public_ip = "44.204.39.53"
ssh_command_master = "ssh -i ~/.ssh/my-kubeadm-lab-key.pem ubuntu@44.204.39.53"
worker_private_ips = [
  "10.0.1.161",
  "10.0.2.9",
  "10.0.1.217",
  "10.0.2.123",
  "10.0.1.198",
  "10.0.2.138",
]

sudo systemctl status containerd
Look for the kubeadm_join_command.sh file if your master script is designed to generate it and distribute it.

