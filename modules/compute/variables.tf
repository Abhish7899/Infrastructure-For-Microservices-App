variable "vpc_id" {
  description = "The VPC ID where application instances and security groups reside"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "List of private app subnet IDs across 2 AZs for EC2 deployment"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "The security group ID of the Application Load Balancer"
  type        = string
}

variable "task_target_group_arn" {
  description = "Target group ARN for task-service (port 3000)"
  type        = string
}

variable "stats_target_group_arn" {
  description = "Target group ARN for stats-service (port 4000)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance size for the private backend application servers"
  type        = string
  default     = "t3.small"
}

variable "environment" {
  description = "Deployment environment name (e.g. prod, dev)"
  type        = string
}
