variable "aws_region" {
  description = "The AWS region"
  default     = "eu-west-1"
}

variable "admin_cidr_ingress" {
  description = "Used to secure all ingress from public networks"
}

variable "key_name" {
  description = "Name of AWS key pair"
}

variable "vpc_cidr" {
  description = "CIDR block for your VPC. IMPORTANT: so subnet automation works use /24."
  default     = "10.75.0.0/24"
}

variable "vpc_name" {
  description = "Name for your VPC"
  default     = "workspace1"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "3"
}

variable "ecs-instance-type" {
  description = "Instance type for the ECS launch configuration"
  default     = "m4.large"
}

# Bamboo settings
variable "bamboo_version" {
  description = "Bamboo Server version (also used by the Agent container)"
  default     = "6.1.1"
}

variable "bamboo_server_external_port" {
  description = "TCP port that the Bamboo LB should listen on (not the container port)"
  default     = "80"
}

# RDS (Postgres) settings
variable "allocated_storage" {
  description = "PostgresDB allocated storage"
  default     = "10"
}

variable "engine_version" {
  description = "PostgresDB version"
  default     = "9.6.2"
}

variable "db_instance_class" {
  description = "DB instance type"
  default     = "db.t2.micro"
}

variable "multi_az" {
  description = "DB is multi-AZ"
  default     = "false"
}

variable "db_username" {
  description = "Postgres DB master username. DO NOT USE DEFAULT IN PRODUCTION."
  default     = "master"
}

variable "db_password" {
  description = "Postgres DB master password. DO NOT USE DEFAULT IN PRODUCTION."
  default     = "changemerightmeow"
}
