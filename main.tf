# main.tf

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# --- Networking (VPC, Subnets, Internet Gateway) ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0" # Always pin to a specific version!

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # For lab, a single NAT Gateway is cost-effective
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "Dev"
    Project     = "KubeadmLab"
    ManagedBy   = "Terraform"
  }
}

# --- Security Groups ---
resource "aws_security_group" "kubernetes_sg" {
  name_prefix = "${var.cluster_name}-kubernetes-"
  description = "Security group for Kubernetes nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere (restrict in production)
  }

  ingress {
    from_port   = 6443 # Kubernetes API server
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow API access (restrict in production)
  }

  ingress {
    from_port   = 10250 # Kubelet API
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Allow within VPC
  }

  ingress {
    from_port   = 30000
    to_port     = 32767 # NodePort range
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow NodePort access (restrict in production)
  }

  # For Calico/Flannel (adjust based on your CNI choice)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols for internal cluster comms
    self        = true # Allow from instances in the same SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name = "${var.cluster_name}-kubernetes-sg"
  }
}

# --- Key Pair for SSH ---
resource "aws_key_pair" "kubeadm_key" {
  key_name   = "${var.cluster_name}-key"
  public_key = var.public_key # Provide your public SSH key
}

# --- EC2 Instances ---

# Data source to get the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical's account ID
}

# Master Node
resource "aws_instance" "master" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_master
  key_name                    = aws_key_pair.kubeadm_key.key_name
  vpc_security_group_ids      = [aws_security_group.kubernetes_sg.id]
  subnet_id                   = module.vpc.public_subnets[0] # Place master in public subnet for direct access (lab setup)
  associate_public_ip_address = true
  user_data_base64 = base64encode(templatefile("${path.module}/user-data-master.sh", {
    kubernetes_version         = var.kubernetes_version
    pod_cidr                   = var.pod_cidr
    # Calculate the major.minor version string (e.g., "v1.28" from "1.28.1")
    # using HCL string functions and string interpolation.
    kubernetes_release_version_segment = "v${replace(var.kubernetes_version, "/\\.[^.]*$/", "")}"
  }))
  tags = {
    Name = "${var.cluster_name}-master"
    Role = "master"
  }
}

# Worker Nodes
resource "aws_instance" "worker" {
  count                       = var.worker_node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_worker
  key_name                    = aws_key_pair.kubeadm_key.key_name
  vpc_security_group_ids      = [aws_security_group.kubernetes_sg.id]
  subnet_id                   = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)] # Distribute across private subnets
  associate_public_ip_address = false # Workers in private subnets (more secure)
  user_data_base64            = base64encode(templatefile("${path.module}/user-data-worker.sh", {
    kubernetes_version = var.kubernetes_version
  }))

  tags = {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
  }
}
