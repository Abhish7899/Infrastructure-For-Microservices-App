output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.postgres.id
}

output "db_instance_endpoint" {
  description = "The connection endpoint for PostgreSQL (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "db_instance_address" {
  description = "The hostname of the RDS PostgreSQL instance"
  value       = aws_db_instance.postgres.address
}

output "db_instance_port" {
  description = "The database connection port"
  value       = aws_db_instance.postgres.port
}

output "db_master_user_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret holding the master user credentials"
  value       = try(aws_db_instance.postgres.master_user_secret[0].secret_arn, null)
}

output "database_security_group_id" {
  description = "The ID of the RDS security group"
  value       = aws_security_group.db.id
}
