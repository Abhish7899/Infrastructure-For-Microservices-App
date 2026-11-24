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
    description = "Allow all outbound traffic to backend instances"
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
# Target Groups with Health Checks & Deregistration Delay
# -----------------------------------------------------------------------------

# 1. Target Group: task-service (Port 3000)
resource "aws_lb_target_group" "task_service" {
  name                 = "tg-${var.environment}-task"
  port                 = 3000
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "3000"
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
    Name    = "tg-${var.environment}-task"
    Service = "task-service"
  }
}

# 2. Target Group: stats-service (Port 4000)
resource "aws_lb_target_group" "stats_service" {
  name                 = "tg-${var.environment}-stats"
  port                 = 4000
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "4000"
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
    Name    = "tg-${var.environment}-stats"
    Service = "stats-service"
  }
}

# -----------------------------------------------------------------------------
# HTTP Listener & Path-Based Routing Rules
# -----------------------------------------------------------------------------

# Port 80 Listener with fixed-response 404 fallback
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({ error = "Route not found" })
      status_code  = "404"
    }
  }
}

# Listener Rule Priority 10: Route /api/tasks and /api/tasks/* to task-service
resource "aws_lb_listener_rule" "task_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.task_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/tasks", "/api/tasks/*"]
    }
  }
}

# Listener Rule Priority 20: Route /api/stats and /api/stats/* to stats-service
resource "aws_lb_listener_rule" "stats_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stats_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/stats", "/api/stats/*"]
    }
  }
}
