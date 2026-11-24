variable "aws_region" {
  description = "AWS region for provisioning resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones in ap-southeast-2"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private app subnets (Kubernetes nodes)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "isolated_db_subnet_cidrs" {
  description = "CIDR blocks for isolated database subnets (RDS PostgreSQL)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "single_nat_gateway" {
  description = "Provision a single NAT Gateway for cost-optimization"
  type        = bool
  default     = true
}

variable "master_instance_type" {
  description = "EC2 instance size for the Kubernetes Master node"
  type        = string
  default     = "c7i-flex.large"
}

variable "worker_instance_type" {
  description = "EC2 instance size for the Kubernetes Worker nodes"
  type        = string
  default     = "t3.small"
}

variable "s3_artifactory_bucket_name" {
  description = "Name of the S3 artifactory bucket for Ansible SSM transport"
  type        = string
  default     = "e-commerce-artifactory"
}

variable "db_instance_class" {
  description = "RDS instance class for PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage size in GiB for PostgreSQL"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "taskdb"
}

variable "db_master_username" {
  description = "Master username for PostgreSQL"
  type        = string
  default     = "dbadmin"
}

variable "skip_final_snapshot" {
  description = "Whether to skip taking a final snapshot before destroying the database"
  type        = bool
  default     = true
}
