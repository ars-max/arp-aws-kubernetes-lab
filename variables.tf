# variables.tf

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1" # Or your preferred region
}

variable "cluster_name" {
  description = "Name for the Kubeadm cluster"
  type        = string
  default     = "my-kubeadm-lab"
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g., 1.28.0)"
  type        = string
  default     = "1.28.5" # Match with kubeadm compatible version (e.g., 1.28.5-00)
}

variable "instance_type_master" {
  description = "EC2 instance type for the master node"
  type        = string
  default     = "t3.medium" # t2.medium might also work, but t3.medium is better for a lab
}

variable "instance_type_worker" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.small" # Cost-effective for lab
}

variable "worker_node_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 2
}

variable "public_key" {
  description = "Your SSH public key content (e.g., from ~/.ssh/id_rsa.pub)"
  type        = string
  sensitive   = true # Mark as sensitive as it can contain private info
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCVpDsQl4qwU7CT6bdyyVWZ5QOgb+zKZ4dtSjxQQSo0Jt4o4D4OkhNFVVIUrdMJOIRWsnXK6l1UD+as7BX5R6IODcvOTJoaL6fa407tT0PxctyB5SyeWqhUfB3BRlnuhBbEAQLFqtPKuX36QgXXCeK5qEXMhuz+JbHu+eOmnjV6G2wk0gPScf8zeZbGexM4e64UwnK/yE6pX83lq51A/XqjCKYCCjwXL1Z+YPczqaxw9o5H0p2LSmeRsimKvjSO5MnUxtoWO34F1ozn+pMyQdCPU+v1RxRpCyogxRIJfyH30vmPDGtPp4UfFs4nbcJg/LCTMuiB6fmSLayoD299Zwo+iViHqzcI0Ef6LogpjKOpQwzL+zPgvzcVAfBVvevXuB+ZT4TCc4nSzhuKhPjdzwwGCiG1ehw+8TjIk0zHwnTo2HbxnDmQIKPnjJr08PvH8EsMOQmUINSHCPtjS+u3bBoNJK/z9YRe+SQPdfJCY7jYHC4cnUSBjFUL9Q7yVLawbygYqvnA+9nsYoNKPrdMcuqaE05b/DWLJek47s1HrHwjtKHmSMtjrsQSudB7uEeC3NFLTCeq/bhacdEP01uvHYUinCMjGl4NvAK6UoGxolmMUPr50YDM37DCrtffvkRyBoVeWyLbsGSeUL0fqy8GziPVbceDIrGiaQrqj3SmGmmaXw== Admin@LAPTOP-QH6KA3VT"
}

variable "pod_cidr" {
  description = "CIDR range for Kubernetes Pods (e.g., 10.244.0.0/16 for Flannel)"
  type        = string
  default     = "10.244.0.0/16" # Flannel default
}