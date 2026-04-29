terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Stores Terraform state in S3 so every pipeline run shares the same state.
  # Create this bucket manually once before first pipeline run:
  #   aws s3 mb s3://aupp-sms-tfstate --region us-east-1
  backend "s3" {
    bucket = "aupp-sms-tfstate"
    key    = "student-mgmt/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ── SSH Key Pair ──────────────────────────────────────────────
resource "aws_key_pair" "sms_key" {
  key_name   = "sms-deploy-key"
  public_key = var.ec2_public_key
}

# ── Security Group ─────────────────────────────────────────────
resource "aws_security_group" "sms_sg" {
  name        = "sms-security-group"
  description = "Ports for Student Management System"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API Gateway"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sms-sg" }
}

# ── Latest Ubuntu 22.04 AMI ────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ── EC2 Instance ───────────────────────────────────────────────
resource "aws_instance" "sms_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.sms_key.key_name
  vpc_security_group_ids = [aws_security_group.sms_sg.id]
  user_data              = file("${path.module}/user_data.sh")

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "sms-server"
    Environment = "production"
    Project     = "student-management-system"
  }
}

# ── Elastic IP (static — survives stop/start) ──────────────────
resource "aws_eip" "sms_eip" {
  instance = aws_instance.sms_server.id
  domain   = "vpc"

  tags = { Name = "sms-eip" }
}
