# Custom Multi-AZ VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc-${var.environment}"
  }
}

# Internet Gateway for Public Internet Ingress/Egress
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.environment}"
  }
}

# 1. Public Subnets (Public ALB & NAT Gateways)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-${var.environment}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }
}

# 2. Private App Subnets (Self-managed Vanilla Kubernetes Master & Worker Nodes)
resource "aws_subnet" "private_app" {
  count                   = length(var.private_app_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_app_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-${var.environment}-private-app-${var.availability_zones[count.index]}"
    Tier = "private-app"
  }
}

# 3. Isolated Database Subnets (Amazon RDS PostgreSQL 16)
resource "aws_subnet" "isolated_db" {
  count                   = length(var.isolated_db_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.isolated_db_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-${var.environment}-isolated-db-${var.availability_zones[count.index]}"
    Tier = "isolated-db"
  }
}

# Elastic IP(s) for NAT Gateway(s) - AWS Provider v5 syntax (domain = "vpc")
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = {
    Name = "eip-${var.environment}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway(s) placed in Public Subnet(s)
resource "aws_nat_gateway" "nat" {
  count         = var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-${var.environment}-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# -----------------------------------------------------------------------------
# Route Tables & Subnet Associations
# -----------------------------------------------------------------------------

# Public Route Table -> Routes outbound traffic to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rt-${var.environment}-public"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private App Route Table(s) -> Routes outbound traffic via NAT Gateway(s)
resource "aws_route_table" "private_app" {
  count  = var.single_nat_gateway ? 1 : length(var.private_app_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.nat[0].id : aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = var.single_nat_gateway ? "rt-${var.environment}-private-app" : "rt-${var.environment}-private-app-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_app" {
  count          = length(var.private_app_subnet_cidrs)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private_app[0].id : aws_route_table.private_app[count.index].id
}

# Isolated Database Route Table -> Strictly local routing within VPC (no default route)
resource "aws_route_table" "isolated_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "rt-${var.environment}-isolated-db"
  }
}

resource "aws_route_table_association" "isolated_db" {
  count          = length(var.isolated_db_subnet_cidrs)
  subnet_id      = aws_subnet.isolated_db[count.index].id
  route_table_id = aws_route_table.isolated_db.id
}
