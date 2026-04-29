variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (t2.medium needed — SonarQube requires 2GB RAM)"
  type        = string
  default     = "t2.medium"
}

variable "ec2_public_key" {
  description = "SSH public key content — stored as GitHub secret EC2_PUBLIC_KEY"
  type        = string
  sensitive   = true
}
