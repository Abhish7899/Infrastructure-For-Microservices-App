output "alb_arn" {
  description = "The Amazon Resource Name (ARN) of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "The public DNS domain name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "The Security Group ID of the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "task_target_group_arn" {
  description = "The ARN of the task-service target group (port 3000)"
  value       = aws_lb_target_group.task_service.arn
}

output "stats_target_group_arn" {
  description = "The ARN of the stats-service target group (port 4000)"
  value       = aws_lb_target_group.stats_service.arn
}

output "http_listener_arn" {
  description = "The ARN of the HTTP listener (port 80)"
  value       = aws_lb_listener.http.arn
}
