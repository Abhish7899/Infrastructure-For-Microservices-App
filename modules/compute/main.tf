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
# Kubernetes Nodes Security Group (Master & Workers)
# -----------------------------------------------------------------------------
resource "aws_security_group" "k8s_nodes" {
  name        = "k8s-nodes-${var.environment}-sg"
  description = "Security Group for self-managed Vanilla Kubernetes master and worker nodes"
  vpc_id      = var.vpc_id

  # Inbound NodePort 30080 from ALB Security Group ONLY
  ingress {
    description     = "Allow Ingress NodePort 30080 from ALB strictly"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Self-referencing rules for Kubernetes internal cluster communication
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "etcd server client API"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Kubelet API, kube-scheduler, kube-controller-manager"
    from_port   = 10250
    to_port     = 10259
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "NodePort Services default range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Flannel/Calico VXLAN (UDP 4789)"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "Flannel VXLAN (UDP 8472)"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
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
    Name = "sg-${var.environment}-k8s-nodes"
  }
}

# -----------------------------------------------------------------------------
# IAM Role & Instance Profile (SSM, ECR ReadOnly, and S3 Artifactory Access)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "k8s_node" {
  name = "role-${var.environment}-k8s-node"

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
    Name = "role-${var.environment}-k8s-node"
  }
}

# Attach AWS Systems Manager Core policy for keyless Ansible access
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.k8s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach Amazon ECR ReadOnly policy to pull container images
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.k8s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Inline policy for Ansible SSM transport via S3 artifactory bucket
resource "aws_iam_role_policy" "ansible_s3" {
  name = "policy-${var.environment}-ansible-s3"
  role = aws_iam_role.k8s_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AnsibleSSMObjectsAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.s3_artifactory_bucket_name}/ansible-ssm/*"
      },
      {
        Sid      = "AnsibleSSMBucketList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.s3_artifactory_bucket_name}"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k8s_node" {
  name = "instance-profile-${var.environment}-k8s-node"
  role = aws_iam_role.k8s_node.name
}

# -----------------------------------------------------------------------------
# Kubernetes Master Node (1x c7i-flex.large in Private Subnet)
# -----------------------------------------------------------------------------
resource "aws_instance" "master" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.master_instance_type
  subnet_id                   = var.private_app_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.k8s_nodes.id]
  iam_instance_profile        = aws_iam_instance_profile.k8s_node.name
  associate_public_ip_address = false
  source_dest_check           = false # Critical for Kubernetes CNI routing

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name        = "${var.environment}-k8s-master"
    Environment = var.environment
    Role        = "k8s-master"
  }
}

# -----------------------------------------------------------------------------
# Kubernetes Worker Nodes (2x t3.small across both Private Subnets)
# -----------------------------------------------------------------------------
resource "aws_instance" "worker" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.worker_instance_type
  subnet_id                   = var.private_app_subnet_ids[count.index]
  vpc_security_group_ids      = [aws_security_group.k8s_nodes.id]
  iam_instance_profile        = aws_iam_instance_profile.k8s_node.name
  associate_public_ip_address = false
  source_dest_check           = false # Critical for Kubernetes CNI routing

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name        = "${var.environment}-k8s-worker-${count.index + 1}"
    Environment = var.environment
    Role        = "k8s-worker"
  }
}

# -----------------------------------------------------------------------------
# Register ONLY Worker Nodes to ALB Target Group (Port 30080)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group_attachment" "workers" {
  count            = 2
  target_group_arn = var.ingress_target_group_arn
  target_id        = aws_instance.worker[count.index].id
  port             = 30080
}

# -----------------------------------------------------------------------------
# Amazon ECR Repositories & Retention Lifecycle Policy
# -----------------------------------------------------------------------------
locals {
  ecr_repos = ["task-service", "stats-service", "frontend-service"]
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
