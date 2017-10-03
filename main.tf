# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

## EC2
### Network
data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block            = "${var.vpc_cidr}"
  enable_dns_hostnames  = "true"
  tags {
    Name = "${var.vpc_name}"
  }
}

resource "aws_subnet" "main" {
  count             = "${var.az_count}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 2, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"
  tags {
    Name = "${aws_vpc.main.tags.Name}-${count.index}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "${aws_vpc.main.tags.Name}"
  }
}

#### Note: Public subnets only
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "a" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.main.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

### Security
resource "aws_security_group" "ecs_instance" {
  vpc_id      = "${aws_vpc.main.id}"
  name        = "ecs-instance"

  ingress {
    protocol  = "tcp"
    from_port = 8085
    to_port   = 8085
    self      = "true"

    security_groups = [
      "${aws_security_group.alb_sg.id}"
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 54663
    to_port   = 54663
    self      = "true"
  }

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidr_blocks = [
      "${var.admin_cidr_ingress}"
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_sg" {
  vpc_id = "${aws_vpc.main.id}"
  name   = "bamboo-alb"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = [
      "${var.admin_cidr_ingress}"
    ],
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "efs_sg" {
  vpc_id = "${aws_vpc.main.id}"
  name   = "efs"

  ingress {
    protocol  = "tcp"
    from_port = 2049
    to_port   = 2049
    security_groups = [
      "${aws_security_group.ecs_instance.id}"
    ]
  }

  egress {
    protocol  = "tcp"
    from_port = 2049
    to_port   = 2049
    security_groups = [
      "${aws_security_group.ecs_instance.id}"
    ]
  }
}

resource "aws_security_group" "bamboo_db_sg" {
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    protocol  = "tcp"
    from_port = 5432
    to_port   = 5432
    security_groups = [
      "${aws_security_group.ecs_instance.id}"
    ]
  }

  egress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0
    security_groups = [
      "${aws_security_group.ecs_instance.id}"
    ]
  }
}

# EFS
resource "aws_efs_file_system" "bamboo_home" {}

resource "aws_efs_mount_target" "bamboo_home" {
  file_system_id  = "${aws_efs_file_system.bamboo_home.id}"
  count           = "${var.az_count}"
  subnet_id       = "${element("${aws_subnet.main.*.id}", count.index)}"
  security_groups = [
    "${aws_security_group.efs_sg.id}"
  ]
}

### RDS (Postgres)
resource "aws_db_subnet_group" "bamboo_db_subnet_group" {
  name       = "bamboo_db_subnet_group"
  subnet_ids = ["${aws_subnet.main.*.id}"]
}

resource "aws_db_instance" "bamboo_db" {
  identifier_prefix       = "bamboo-db-"
  engine                  = "postgres"
  instance_class          = "${var.db_instance_class}"
  engine_version          = "${var.engine_version}"
  allocated_storage       = "${var.allocated_storage}"
  storage_type            = "gp2"
  name                    = "bamboo"
  multi_az                = "${var.multi_az}"
  username                = "${var.db_username}"
  password                = "${var.db_password}"
  db_subnet_group_name    = "${aws_db_subnet_group.bamboo_db_subnet_group.name}"
  skip_final_snapshot     = "true" # WARNING
  vpc_security_group_ids  = [
    "${aws_security_group.bamboo_db_sg.id}"
  ]
}

### Compute
data "aws_ami" "amzn_ecs_optimized" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-2017.03.f-amazon-ecs-optimized"]
  }
}

data "template_file" "ecs_user_data" {
  template = "${file("${path.module}/ecs_user_data.txt")}"

  vars {
    ecs_cluster_name  = "${aws_ecs_cluster.bamboo.name}"
    efs_id            = "${aws_efs_file_system.bamboo_home.id}"
    efs_region        = "${var.aws_region}"
  }
}

resource "aws_launch_configuration" "bamboo_ecs" {
  name_prefix                 = "bamboo-ecs-"
  key_name                    = "${var.key_name}"
  image_id                    = "${data.aws_ami.amzn_ecs_optimized.id}"
  instance_type               = "${var.ecs-instance-type}"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs_instance.name}"
  user_data                   = "${data.template_file.ecs_user_data.rendered}"
  associate_public_ip_address = true
  security_groups             = [ "${aws_security_group.ecs_instance.id}" ]

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    "aws_efs_mount_target.bamboo_home",
    "aws_db_instance.bamboo_db"
  ]
}

resource "aws_autoscaling_group" "bamboo_ecs" {
  name_prefix           = "bamboo-ecs-"
  min_size              = "${var.az_count}"
  max_size              = 10
  launch_configuration  = "${aws_launch_configuration.bamboo_ecs.name}"
  health_check_type     = "EC2"
  vpc_zone_identifier   = ["${aws_subnet.main.*.id}"]
}

# IAM

resource "aws_iam_instance_profile" "ecs_instance" {
  name  = "ecs-instance-profile"
  role  = "${aws_iam_role.ecs_instance.name}"
}

resource "aws_iam_role" "ecs_instance" {
  name = "ecs-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_instance" {
  name    = "ecs_instance_policy"
  role    = "${aws_iam_role.ecs_instance.name}"

  policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:DeregisterContainerInstance",
                "ecs:DiscoverPollEndpoint",
                "ecs:Poll",
                "ecs:RegisterContainerInstance",
                "ecs:StartTelemetrySession",
                "ecs:UpdateContainerInstancesState",
                "ecs:Submit*",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "ecs_service" {
  name = "ecs-service-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "ecs_service_policy"
  role = "${aws_iam_role.ecs_service.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

## ALB

resource "aws_alb_target_group" "bamboo_ecs" {
  name     = "bamboo-ecs"
  port     = "8085"
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
  health_check {
    path      = "/"
    protocol  = "HTTP"
    matcher   = "200,302" # Includes 302 as / appears to redirect
  }
}

resource "aws_alb" "bamboo_alb" {
  name            = "bamboo-alb"
  subnets         = ["${aws_subnet.main.*.id}"]
  security_groups = ["${aws_security_group.alb_sg.id}"]
}

resource "aws_alb_listener" "bamboo_alb" {
  load_balancer_arn = "${aws_alb.bamboo_alb.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.bamboo_ecs.id}"
    type             = "forward"
  }
}

### Cloudwatch Logs
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "bamboo-ecs-group/ecs"
  retention_in_days = 1
}

### ECS

resource "aws_ecs_cluster" "bamboo" {
  name = "bamboo"
}

data "template_file" "bamboo_server_task" {
  template = "${file("${path.module}/bamboo-server-task.json")}"
}

resource "aws_ecs_task_definition" "bamboo_server" {
  family                = "bamboo-server"
  container_definitions = "${data.template_file.bamboo_server_task.rendered}"
  network_mode          = "bridge"
  volume {
    name      = "efs-bamboo-home"
    host_path = "/efs/bamboo/home/bamboo"
  }
}

resource "aws_ecs_service" "bamboo_server" {
  name            = "bamboo-server"
  cluster         = "${aws_ecs_cluster.bamboo.id}"
  task_definition = "${aws_ecs_task_definition.bamboo_server.arn}"
  desired_count   = 1

  placement_strategy {
    type  = "spread"
    field = "host"
  }
  iam_role        = "${aws_iam_role.ecs_service.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.bamboo_ecs.id}"
    container_name   = "bamboo-server"
    container_port   = "8085"
  }

  depends_on = [
    "aws_iam_role_policy.ecs_service",
    "aws_alb_listener.bamboo_alb",
  ]
}

data "template_file" "bamboo_agent_task" {
  template = "${file("${path.module}/bamboo-agent-task.json")}"

  vars {
    bamboo_server_url   = "${aws_alb.bamboo_alb.dns_name}"
    log_group_region    = "${var.aws_region}"
    log_group_name      = "${aws_cloudwatch_log_group.ecs.name}"
  }
}

resource "aws_ecs_task_definition" "bamboo_agent" {
  family                = "bamboo-agent"
  container_definitions = "${data.template_file.bamboo_agent_task.rendered}"
  network_mode          = "bridge"
}

resource "aws_ecs_service" "bamboo_agent" {
  name            = "bamboo-agent"
  cluster         = "${aws_ecs_cluster.bamboo.id}"
  task_definition = "${aws_ecs_task_definition.bamboo_agent.arn}"
  desired_count   = 1

  placement_strategy {
    type  = "spread"
    field = "host"
  }
  # iam_role        = "${aws_iam_role.ecs_service.name}"

  depends_on = [
    "aws_ecs_service.bamboo_server",
  ]
}
