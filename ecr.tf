locals {
  ecr_repositories = ["task-service", "stats-service"]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.ecr_repositories)

  name                 = each.key
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each = aws_ecr_repository.services

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain only the last 10 tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Encrypted SSM Parameter Store holding the PostgreSQL DATABASE_URL
resource "aws_ssm_parameter" "database_url" {
  name        = "/${var.project_name}/${var.environment}/database-url"
  description = "PostgreSQL DATABASE_URL connection string for task-service"
  type        = "SecureString"
  value       = "postgresql://${var.db_username}:${random_password.db_password.result}@${module.rds.db_instance_address}:${module.rds.db_instance_port}/${var.db_name}"

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
