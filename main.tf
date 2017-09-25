# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

## EC2
### Network

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = "10.75.0.0/24"
  tags {
    Name = "workspace1"
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
    from_port = 80
    to_port   = 80
    cidr_blocks = [
      "${var.admin_cidr_ingress}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb_sg" {
  vpc_id = "${aws_vpc.main.id}"
  name   = "bamboo-alb"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = [
      "${var.admin_cidr_ingress}",
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
    ecs_cluster_name = "${aws_ecs_cluster.bamboo.name}"
  }
}

resource "aws_launch_configuration" "bamboo_ecs" {
  name_prefix                 = "bamboo-ecs-"
  image_id                    = "${data.aws_ami.amzn_ecs_optimized.id}"
  instance_type               = "${var.ecs-instance-type}"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs_instance.name}"
  user_data                   = "${data.template_file.ecs_user_data.rendered}"
  associate_public_ip_address = true
  security_groups             = [ "${aws_security_group.ecs_instance.id}" ]

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_subnet_ids" "main" {
  vpc_id = "${aws_vpc.main.id}"
  # depends_on = ["aws_vpc.main"]
}

resource "aws_autoscaling_group" "bamboo_ecs" {
  name_prefix           = "bamboo-ecs-"
  min_size              = "${var.az_count}"
  max_size              = 10
  launch_configuration  = "${aws_launch_configuration.bamboo_ecs.name}"
  health_check_type     = "EC2"
  vpc_zone_identifier   = [ "${data.aws_subnet_ids.main.ids}" ]
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
                "logs:CreateLogStream",
                "logs:PutLogEvents"
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
}

resource "aws_alb" "bamboo_alb" {
  name            = "bamboo-alb"
  subnets         = ["${aws_subnet.main.*.id}"]
  security_groups = ["${aws_security_group.lb_sg.id}"]
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

### ECS

resource "aws_ecs_cluster" "bamboo" {
  name = "bamboo"
}

data "template_file" "task_definition" {
  template = "${file("${path.module}/task-definition.json")}"
}

resource "aws_ecs_task_definition" "bamboo-server" {
  family                = "bamboo-server"
  container_definitions = "${data.template_file.task_definition.rendered}"
  network_mode          = "bridge"
  volume {
    name      = "efs-bamboo-home"
    host_path = "/efs/bamboo/home/bamboo"
  }
}

resource "aws_ecs_service" "bamboo-server" {
  name            = "bamboo-server"
  cluster         = "${aws_ecs_cluster.bamboo.id}"
  task_definition = "${aws_ecs_task_definition.bamboo-server.arn}"
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
