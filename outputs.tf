output "cluster_name" {
  description = "Name of the Amazon EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint URL for Amazon EKS control plane API"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "Connection endpoint for Amazon RDS PostgreSQL instance"
  value       = module.rds.db_instance_endpoint
}

output "task_service_ecr_url" {
  description = "Repository URL for task-service Amazon ECR"
  value       = aws_ecr_repository.services["task-service"].repository_url
}

output "stats_service_ecr_url" {
  description = "Repository URL for stats-service Amazon ECR"
  value       = aws_ecr_repository.services["stats-service"].repository_url
}

output "configure_kubectl" {
  description = "Exact AWS CLI command to update local kubeconfig for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "ssm_database_url_parameter" {
  description = "SSM Parameter Store name storing the encrypted DATABASE_URL"
  value       = aws_ssm_parameter.database_url.name
}
