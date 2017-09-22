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

### Compute
data "aws_ami" "amzn-ecs-optimized" {
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

resource "aws_launch_configuration" "bamboo-ecs" {
  name_prefix   = "bamboo-ecs-"
  image_id      = "${data.aws_ami.amzn-ecs-optimized.id}"
  instance_type = "${var.ecs-instance-type}"
  user_data     = "${data.template_file.ecs_user_data.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_subnet_ids" "main" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_autoscaling_group" "bamboo-ecs" {
  name_prefix           = "bamboo-ecs-"
  max_size              = 0
  min_size              = 10
  launch_configuration  = "${aws_launch_configuration.bamboo-ecs.name}"
  health_check_type     = "EC2"
  vpc_zone_identifier   = [ "${data.aws_subnet_ids.main.ids}" ]
}

### ECS

resource "aws_ecs_cluster" "bamboo" {
  name = "bamboo"
}

# resource "aws_ecs_service" "bamboo-server" {
#   name            = "bamboo"
#   cluster         = "${aws_ecs_cluster.foo.id}"
#   task_definition = "${aws_ecs_task_definition.mongo.arn}"
#   desired_count   = 3
#   iam_role        = "${aws_iam_role.foo.arn}"
#   depends_on      = ["aws_iam_role_policy.foo"]
#
#   placement_strategy {
#     type  = "binpack"
#     field = "cpu"
#   }
#
#   load_balancer {
#     elb_name       = "${aws_elb.foo.name}"
#     container_name = "mongo"
#     container_port = 8080
#   }
#
#   placement_constraints {
#     type       = "memberOf"
#     expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
#   }
# }
