output "alb_endpoint" {
  value = "http://${aws_alb.bamboo_alb.dns_name}/"
}

output "database_url" {
  value = "jdbc:postgresql://${aws_db_instance.bamboo_db.endpoint}/${aws_db_instance.bamboo_db.name}"
}

output "db_username" {
  value = "${aws_db_instance.bamboo_db.username}"
}
