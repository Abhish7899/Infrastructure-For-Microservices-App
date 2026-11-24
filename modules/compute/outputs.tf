output "instance_ids" {
  description = "List of IDs of the private EC2 backend instances"
  value       = aws_instance.app[*].id
}

output "instance_private_ips" {
  description = "List of private IP addresses of the EC2 backend instances"
  value       = aws_instance.app[*].private_ip
}

output "app_security_group_id" {
  description = "Security Group ID of the private backend application servers"
  value       = aws_security_group.app.id
}

output "iam_role_arn" {
  description = "IAM Role ARN attached to the EC2 backend instances"
  value       = aws_iam_role.app.arn
}

output "task_ecr_repository_url" {
  description = "Repository URL for task-service Amazon ECR"
  value       = aws_ecr_repository.services["task-service"].repository_url
}

output "stats_ecr_repository_url" {
  description = "Repository URL for stats-service Amazon ECR"
  value       = aws_ecr_repository.services["stats-service"].repository_url
}
