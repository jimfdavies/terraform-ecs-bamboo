output "alb_endpoint" {
  value = "http://${aws_alb.bamboo_alb.dns_name}/"
}

output "broker_url" {
  value = "nio://${aws_elb.bamboo_broker_elb.dns_name}:54663?wireFormat.maxInactivityDuration=300000"
}

output "database_url" {
  value = "jdbc:postgresql://${aws_db_instance.bamboo_db.endpoint}/${aws_db_instance.bamboo_db.name}"
}

output "db_username" {
  value = "${aws_db_instance.bamboo_db.username}"
}

output "db_password" {
  value = "Take from variables.tf or your command line."
}
