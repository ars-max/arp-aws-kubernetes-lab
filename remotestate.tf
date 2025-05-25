terraform {
  backend "s3" {
    bucket         = "my-kube-terraform-state-bucket0331"  # Replace with your S3 bucket name
    key            = "terraform/state/terraform.tfstate"  # Path to the state file within the bucket
    region         = "us-east-1"  # Replace with your AWS region
    dynamodb_table = "terraform-locks"  # Replace with your DynamoDB table name
    encrypt        = true  # Encrypt the state file at rest
  }
}