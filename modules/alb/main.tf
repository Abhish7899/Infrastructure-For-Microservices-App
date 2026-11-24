# Security Group for Public Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "alb-${var.environment}-sg"
  description = "Security Group for Public Internet-Facing Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound HTTP from public internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic to backend K8s worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.environment}-alb"
  }
}

# Public Internet-Facing Application Load Balancer
resource "aws_lb" "main" {
  name               = "alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "alb-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# Single Target Group: k8s-ingress-tg (Port 30080 NodePort)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "k8s_ingress" {
  name                 = "k8s-ingress-tg-${var.environment}"
  port                 = 30080
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/healthz"
    protocol            = "HTTP"
    port                = "30080"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "k8s-ingress-tg-${var.environment}"
    Tier = "ingress"
  }
}

# -----------------------------------------------------------------------------
# HTTP Listener (Port 80) Forwarding All Traffic to Ingress Target Group
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_ingress.arn
  }
}
