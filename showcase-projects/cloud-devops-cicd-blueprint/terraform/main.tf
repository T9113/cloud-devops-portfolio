terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Production Best Practice: Remote State Backend
  # backend "s3" {
  #   bucket         = "cloud-blueprint-tf-state-prod"
  #   key            = "cloud-blueprint/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "cloud-blueprint-tf-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "CloudDevOpsBlueprint"
      Owner       = "Tayyab Masood"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ==========================================
# 1. Multi-AZ VPC Architecture
# ==========================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "blueprint-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "blueprint-${var.environment}-igw"
  }
}

# Public Subnets across 2 Availability Zones
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, 0)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "blueprint-${var.environment}-public-1"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, 1)
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "blueprint-${var.environment}-public-2"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private Subnets for secure application workloads
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 2)
  availability_zone = "${var.aws_region}a"

  tags = {
    Name                              = "blueprint-${var.environment}-private-1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 3)
  availability_zone = "${var.aws_region}b"

  tags = {
    Name                              = "blueprint-${var.environment}-private-2"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ==========================================
# 2. NAT Gateway & Route Tables
# ==========================================
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "blueprint-${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "blueprint-${var.environment}-nat-gw"
  }
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "blueprint-${var.environment}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "blueprint-${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# ==========================================
# 3. Security Group with Least-Privilege Rules
# ==========================================
resource "aws_security_group" "app_sg" {
  name        = "blueprint-${var.environment}-app-sg"
  description = "Security group for containerized workload"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS from trusted boundaries"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP inbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "blueprint-${var.environment}-app-sg"
  }
}
