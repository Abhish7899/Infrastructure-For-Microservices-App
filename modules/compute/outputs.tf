output "master_instance_id" {
  description = "The EC2 instance ID of the Kubernetes Master node"
  value       = aws_instance.master.id
}

output "master_private_ip" {
  description = "The private IP address of the Kubernetes Master node"
  value       = aws_instance.master.private_ip
}

output "worker_instance_ids" {
  description = "List of EC2 instance IDs of the Kubernetes Worker nodes"
  value       = aws_instance.worker[*].id
}

output "worker_private_ips" {
  description = "List of private IP addresses of the Kubernetes Worker nodes"
  value       = aws_instance.worker[*].private_ip
}

output "k8s_node_security_group_id" {
  description = "The security group ID of the Kubernetes nodes"
  value       = aws_security_group.k8s_nodes.id
}

output "iam_role_arn" {
  description = "The IAM role ARN attached to the Kubernetes nodes"
  value       = aws_iam_role.k8s_node.arn
}

output "task_ecr_repository_url" {
  description = "Repository URL for task-service Amazon ECR"
  value       = aws_ecr_repository.services["task-service"].repository_url
}

output "stats_ecr_repository_url" {
  description = "Repository URL for stats-service Amazon ECR"
  value       = aws_ecr_repository.services["stats-service"].repository_url
}

output "frontend_ecr_repository_url" {
  description = "Repository URL for frontend-service Amazon ECR"
  value       = aws_ecr_repository.services["frontend-service"].repository_url
}
