terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "shopworthy" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "shopworthy-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.shopworthy.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "shopworthy-public-${count.index}"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "shopworthy" {
  vpc_id = aws_vpc.shopworthy.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.shopworthy.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shopworthy.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security group — overly permissive for demo purposes
resource "aws_security_group" "shopworthy" {
  name        = "shopworthy-${var.environment}"
  description = "ShopWorthy application security group"
  vpc_id      = aws_vpc.shopworthy.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # TODO: restrict to specific IPs before prod
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS PostgreSQL
resource "aws_db_instance" "shopworthy" {
  identifier        = "shopworthy-${var.environment}"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "inventory"
  username = "shopworthy"
  password = var.db_password  # Hardcoded default in variables.tf

  vpc_security_group_ids = [aws_security_group.shopworthy.id]
  db_subnet_group_name   = aws_db_subnet_group.shopworthy.name
  publicly_accessible    = true  # Exposed to internet

  skip_final_snapshot = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_db_subnet_group" "shopworthy" {
  name       = "shopworthy-${var.environment}"
  subnet_ids = aws_subnet.public[*].id
}

# EC2 for application services
resource "aws_instance" "shopworthy" {
  ami           = "ami-0c02fb55956c7d316"  # Amazon Linux 2
  instance_type = "t3.medium"

  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.shopworthy.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker git
    systemctl start docker
    usermod -aG docker ec2-user
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  EOF

  tags = {
    Name        = "shopworthy-${var.environment}"
    Environment = var.environment
  }
}
