terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "task-stats-microservices"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Module: Multi-AZ Custom VPC & Networking
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  isolated_db_subnet_cidrs = var.isolated_db_subnet_cidrs
  single_nat_gateway       = var.single_nat_gateway
  environment              = var.environment
}

# -----------------------------------------------------------------------------
# Module: Public Application Load Balancer
# -----------------------------------------------------------------------------
module "alb" {
  source = "../../modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  environment       = var.environment
}

# -----------------------------------------------------------------------------
# Module: Self-Managed Vanilla Kubernetes Nodes & ECR Repositories
# -----------------------------------------------------------------------------
module "compute" {
  source = "../../modules/compute"

  vpc_id                     = module.vpc.vpc_id
  private_app_subnet_ids     = module.vpc.private_app_subnet_ids
  alb_security_group_id      = module.alb.alb_security_group_id
  ingress_target_group_arn   = module.alb.ingress_target_group_arn
  master_instance_type       = var.master_instance_type
  worker_instance_type       = var.worker_instance_type
  s3_artifactory_bucket_name = var.s3_artifactory_bucket_name
  environment                = var.environment
}

# -----------------------------------------------------------------------------
# Module: Amazon RDS PostgreSQL 16 in Isolated DB Subnets
# -----------------------------------------------------------------------------
module "database" {
  source = "../../modules/database"

  vpc_id                     = module.vpc.vpc_id
  isolated_db_subnet_ids     = module.vpc.isolated_db_subnet_ids
  k8s_node_security_group_id = module.compute.k8s_node_security_group_id
  db_name                    = var.db_name
  master_username            = var.db_master_username
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  skip_final_snapshot        = var.skip_final_snapshot
  environment                = var.environment
}

# -----------------------------------------------------------------------------
# Automated Handoff to Stage 2 (Ansible) & Stage 3 (CI/CD / App Deployment)
# Stored in AWS SSM Parameter Store for Dynamic Retrieval
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "alb_dns" {
  name        = "/${var.environment}/app/alb_dns"
  description = "Public DNS name of the Application Load Balancer"
  type        = "String"
  value       = module.alb.alb_dns_name
  overwrite   = true
}

resource "aws_ssm_parameter" "rds_endpoint" {
  name        = "/${var.environment}/app/rds_endpoint"
  description = "Connection endpoint of Amazon RDS PostgreSQL"
  type        = "String"
  value       = module.database.db_instance_endpoint
  overwrite   = true
}

resource "aws_ssm_parameter" "ecr_task_repo_url" {
  name        = "/${var.environment}/app/ecr_task_repo_url"
  description = "Amazon ECR Repository URL for task-service"
  type        = "String"
  value       = module.compute.task_ecr_repository_url
  overwrite   = true
}

resource "aws_ssm_parameter" "ecr_stats_repo_url" {
  name        = "/${var.environment}/app/ecr_stats_repo_url"
  description = "Amazon ECR Repository URL for stats-service"
  type        = "String"
  value       = module.compute.stats_ecr_repository_url
  overwrite   = true
}

resource "aws_ssm_parameter" "ecr_frontend_repo_url" {
  name        = "/${var.environment}/app/ecr_frontend_repo_url"
  description = "Amazon ECR Repository URL for frontend-service"
  type        = "String"
  value       = module.compute.frontend_ecr_repository_url
  overwrite   = true
}

resource "aws_ssm_parameter" "master_private_ip" {
  name        = "/${var.environment}/k8s/master_private_ip"
  description = "Private IP address of the Kubernetes Master node for Stage 2 Ansible bootstrap"
  type        = "String"
  value       = module.compute.master_private_ip
  overwrite   = true
}
