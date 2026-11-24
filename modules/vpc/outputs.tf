output "vpc_id" {
  description = "The ID of the provisioned VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The primary CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets (ALB & NAT)"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of IDs of private app subnets (EC2 backend nodes)"
  value       = aws_subnet.private_app[*].id
}

output "isolated_db_subnet_ids" {
  description = "List of IDs of isolated database subnets (RDS PostgreSQL)"
  value       = aws_subnet.isolated_db[*].id
}

output "nat_gateway_ips" {
  description = "List of Elastic IP addresses attached to the NAT Gateway(s)"
  value       = aws_eip.nat[*].public_ip
}
