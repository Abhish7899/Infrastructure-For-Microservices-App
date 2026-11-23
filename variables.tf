variable "region" {
  description = "AWS region for provisioning resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name prefix used for resource naming"
  type        = string
  default     = "microservice-app"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_version" {
  description = "Kubernetes version for Amazon EKS"
  type        = string
  default     = "1.37"
}

variable "db_name" {
  description = "Database name for the PostgreSQL instance"
  type        = string
  default     = "tasks_db"
}

variable "db_username" {
  description = "Master username for PostgreSQL"
  type        = string
  default     = "postgres"
}
