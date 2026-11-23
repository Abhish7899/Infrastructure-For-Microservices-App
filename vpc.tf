locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = "10.0.0.0/16"

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # 2 Public Subnets, 2 Private App Subnets, and 2 Private Database Subnets
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets  = ["10.0.10.0/24", "10.0.11.0/24"]
  database_subnets = ["10.0.20.0/24", "10.0.21.0/24"]

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Cost-optimized single NAT Gateway
  enable_nat_gateway = true
  single_nat_gateway = true

  # Database Subnet Group for RDS
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # EKS mandatory subnet tags
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "karpenter.sh/discovery"                      = local.cluster_name
  }

  database_subnet_tags = {
    "Type" = "database-subnets"
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
