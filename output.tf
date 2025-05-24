# outputs.tf

output "master_public_ip" {
  description = "Public IP of the Kubernetes master node"
  value       = aws_instance.master.public_ip
}

output "master_private_ip" {
  description = "Private IP of the Kubernetes master node"
  value       = aws_instance.master.private_ip
}

output "worker_private_ips" {
  description = "Private IPs of the Kubernetes worker nodes"
  value       = aws_instance.worker.*.private_ip
}

output "ssh_command_master" {
  description = "SSH command to connect to the master node"
  value       = "ssh -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${aws_instance.master.public_ip}"
}

output "kubeconfig_instructions" {
  description = "Instructions to retrieve kubeconfig from master node"
  value       = <<-EOT
    To get your kubeconfig file:
    1. SSH into the master node: ${aws_instance.master.public_ip}
    2. Run: sudo cat /etc/kubernetes/admin.conf > kubeconfig
    3. Copy 'kubeconfig' file to your local machine: scp -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${aws_instance.master.public_ip}:~/kubeconfig .
    4. Set KUBECONFIG environment variable: export KUBECONFIG=./kubeconfig
    5. Test with: kubectl get nodes
  EOT
}