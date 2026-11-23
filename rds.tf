resource "random_password" "db_password" {
  length  = 24
  special = false # Exclude special characters (@, /, :) that break PostgreSQL connection URLs
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Dedicated security group for RDS PostgreSQL database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow PostgreSQL inbound strictly from EKS worker nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Environment = var.environment
    Terraform   = "true"
  }
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-${var.environment}-postgres"

  engine               = "postgres"
  engine_version       = "16"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 50

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432

  # Use the password provided instead of AWS-managed secrets
  manage_master_user_password = false

  # Private database subnets
  publicly_accessible    = false
  create_db_subnet_group = false
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Clean teardown for DevOps practice environments
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
