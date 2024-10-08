output "frontend_alb_dns" {
  value = aws_alb.frontend_alb.dns_name
}
