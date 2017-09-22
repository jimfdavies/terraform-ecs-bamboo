variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "eu-west-1"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "3"
}

variable "ecs-instance-type" {
  description = "Instance type for the ECS launch configuration"
  default     = "m4.large"
}
