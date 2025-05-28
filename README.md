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

sudo systemctl status containerd
Look for the kubeadm_join_command.sh file if your master script is designed to generate it and distribute it.

