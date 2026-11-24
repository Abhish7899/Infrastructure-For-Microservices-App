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

output "ingress_target_group_arn" {
  description = "The ARN of the k8s-ingress-tg target group (port 30080)"
  value       = aws_lb_target_group.k8s_ingress.arn
}

output "http_listener_arn" {
  description = "The ARN of the HTTP listener (port 80)"
  value       = aws_lb_listener.http.arn
}
