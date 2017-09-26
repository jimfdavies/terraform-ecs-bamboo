output "endpoint" {
  value = "http://${aws_alb.bamboo_alb.dns_name}/"
}
