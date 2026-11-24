# Data source to fetch the latest official Canonical Ubuntu 24.04 LTS AMI (Noble)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*", "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# App Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "app-${var.environment}-sg"
  description = "Security Group for private EC2 backend app servers"
  vpc_id      = var.vpc_id

  # Inbound HTTP 3000 from ALB Security Group ONLY
  ingress {
    description     = "Allow HTTP 3000 for task-service from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Inbound HTTP 4000 from ALB Security Group ONLY
  ingress {
    description     = "Allow HTTP 4000 for stats-service from ALB"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Inbound HTTP 3000 within App SG (internal microservice communication)
  ingress {
    description = "Allow internal HTTP 3000 communication between app nodes"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic (NAT gateway, ECR, RDS, SSM)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.environment}-app"
  }
}

# -----------------------------------------------------------------------------
# IAM Role & Instance Profile (SSM & ECR Access - No SSH Key needed)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "app" {
  name = "role-${var.environment}-app-server"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "role-${var.environment}-app-server"
  }
}

# Attach AWS Systems Manager Core policy for passwordless/keyless Ansible access
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach Amazon ECR ReadOnly policy to pull container images
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "app" {
  name = "instance-profile-${var.environment}-app"
  role = aws_iam_role.app.name
}

# -----------------------------------------------------------------------------
# Private EC2 Instances (Across 2 Availability Zones)
# -----------------------------------------------------------------------------
resource "aws_instance" "app" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_app_subnet_ids[count.index]
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Prevent unintended instance replacement on new AMI release
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name        = "app-server-${var.environment}-${count.index + 1}"
    Environment = var.environment
    Role        = "app-server"
  }
}

# -----------------------------------------------------------------------------
# ALB Target Group Attachments
# -----------------------------------------------------------------------------

# Register both EC2 instances to task-service Target Group (port 3000)
resource "aws_lb_target_group_attachment" "task_service" {
  count            = 2
  target_group_arn = var.task_target_group_arn
  target_id        = aws_instance.app[count.index].id
  port             = 3000
}

# Register both EC2 instances to stats-service Target Group (port 4000)
resource "aws_lb_target_group_attachment" "stats_service" {
  count            = 2
  target_group_arn = var.stats_target_group_arn
  target_id        = aws_instance.app[count.index].id
  port             = 4000
}

# -----------------------------------------------------------------------------
# Amazon ECR Repositories & Retention Lifecycle Policy
# -----------------------------------------------------------------------------
locals {
  ecr_repos = ["task-service", "stats-service"]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.ecr_repos)
  name                 = each.key
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = each.key
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only the last 10 images"
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
