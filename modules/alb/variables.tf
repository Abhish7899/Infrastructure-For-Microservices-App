variable "vpc_id" {
  description = "The VPC ID where ALB and target groups are deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the internet-facing ALB"
  type        = list(string)
}

variable "environment" {
  description = "Deployment environment name (e.g. prod, dev)"
  type        = string
}
