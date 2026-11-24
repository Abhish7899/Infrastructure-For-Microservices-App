output "vpc_id" {
  description = "The ID of the custom VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  value       = module.vpc.private_app_subnet_ids
}

output "isolated_db_subnet_ids" {
  description = "IDs of the isolated database subnets"
  value       = module.vpc.isolated_db_subnet_ids
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "ec2_instance_ids" {
  description = "List of EC2 application server IDs"
  value       = module.compute.instance_ids
}

output "ec2_private_ips" {
  description = "Private IP addresses of the application servers"
  value       = module.compute.instance_private_ips
}

output "rds_endpoint" {
  description = "Amazon RDS PostgreSQL connection endpoint"
  value       = module.database.db_instance_endpoint
}

output "rds_master_user_secret_arn" {
  description = "AWS Secrets Manager Secret ARN holding master database credentials"
  value       = module.database.db_master_user_secret_arn
}

output "task_ecr_url" {
  description = "Amazon ECR URL for task-service container images"
  value       = module.compute.task_ecr_repository_url
}

output "stats_ecr_url" {
  description = "Amazon ECR URL for stats-service container images"
  value       = module.compute.stats_ecr_repository_url
}

output "ssm_parameters" {
  description = "Map of AWS SSM Parameter Store paths holding infrastructure values for Stage 2 & 3 handoff"
  value = {
    alb_dns            = aws_ssm_parameter.alb_dns.name
    rds_endpoint       = aws_ssm_parameter.rds_endpoint.name
    ecr_task_repo_url  = aws_ssm_parameter.ecr_task_repo_url.name
    ecr_stats_repo_url = aws_ssm_parameter.ecr_stats_repo_url.name
  }
}
