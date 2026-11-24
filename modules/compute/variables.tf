variable "vpc_id" {
  description = "The VPC ID where Kubernetes nodes and security groups reside"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "List of private app subnet IDs across 2 AZs for Kubernetes node deployment"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "The security group ID of the Application Load Balancer"
  type        = string
}

variable "ingress_target_group_arn" {
  description = "The target group ARN for k8s-ingress-tg (port 30080)"
  type        = string
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

variable "environment" {
  description = "Deployment environment name (e.g. prod, dev)"
  type        = string
}
