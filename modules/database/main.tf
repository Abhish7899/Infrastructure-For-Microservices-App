# Subnet Group for RDS in Isolated Database Subnets
resource "aws_db_subnet_group" "db" {
  name        = "dbsng-${var.environment}"
  description = "Isolated database subnet group for PostgreSQL"
  subnet_ids  = var.isolated_db_subnet_ids

  tags = {
    Name = "dbsng-${var.environment}"
  }
}

# Dedicated Security Group for RDS PostgreSQL
resource "aws_security_group" "db" {
  name        = "db-${var.environment}-sg"
  description = "Security Group for Amazon RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow inbound PostgreSQL 5432 from Kubernetes nodes strictly"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.k8s_node_security_group_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.environment}-db"
  }
}

# Amazon RDS PostgreSQL 16 Instance
resource "aws_db_instance" "postgres" {
  identifier                  = "rds-${var.environment}-postgres"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = var.instance_class
  allocated_storage           = var.allocated_storage
  max_allocated_storage       = 50
  storage_type                = "gp3"
  storage_encrypted           = true
  multi_az                    = false
  publicly_accessible         = false
  db_subnet_group_name        = aws_db_subnet_group.db.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  db_name                     = var.db_name
  username                    = var.master_username
  manage_master_user_password = true # Auto-generated secret in AWS Secrets Manager (no hardcoded password)
  skip_final_snapshot         = var.skip_final_snapshot
  deletion_protection         = false

  tags = {
    Name = "rds-${var.environment}-postgres"
  }
}
