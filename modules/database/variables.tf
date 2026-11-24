variable "vpc_id" {
  description = "The VPC ID where database and database security groups reside"
  type        = string
}

variable "isolated_db_subnet_ids" {
  description = "List of isolated database subnet IDs across 2 AZs"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID of the EC2 backend compute nodes (allowed to access PostgreSQL on port 5432)"
  type        = string
}

variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "taskdb"
}

variable "master_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "dbadmin"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage size in GiB"
  type        = number
  default     = 20
}

variable "skip_final_snapshot" {
  description = "Whether to skip taking a final DB snapshot before destroying the database"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Deployment environment name (e.g. prod, dev)"
  type        = string
}
