output "alb_endpoint" {
  value = "http://${aws_alb.bamboo_alb.dns_name}/"
}

output "db_endpoint" {
  value = "${aws_db_instance.bamboo_db.endpoint}"
}

output "db_port" {
  value = "${aws_db_instance.bamboo_db.port}"
}
