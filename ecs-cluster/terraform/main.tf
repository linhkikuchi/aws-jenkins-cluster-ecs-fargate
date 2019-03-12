provider "aws" {
  region = "${var.region}"
}

# Where to store the terraform state file
# init with backup config for flexibility
# terraform init --backend-config="bucket=terraform-state-sg" --backend-config="region=ap-southeast-1"
terraform {
  backend "s3" {
    key     = "tf-ecs.tfstate"
  }
}

## generate key pair
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins_generated_key" {
  key_name   = "${var.key_name}"
  public_key = "${tls_private_key.jenkins_key.public_key_openssh}"
  lifecycle {
    ignore_changes = [
      "key_name"
    ]
  }
}

### vpc
resource "aws_vpc" "ecs_cluster_vpc" {
  cidr_block           = "100.0.0.0/22"
  enable_dns_hostnames = true
  enable_dns_support   =  true
  tags {
    Name = "ecs-cluster-vpc"
  }
}

### security group
resource "aws_security_group" "ecs_access_via_nat" {
  name = "ecs-cluster-sg"
  description = "Access to internet via nat instance for private nodes"
  vpc_id = "${aws_vpc.ecs_cluster_vpc.id}"

  # outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "ecs-cluster-sg"
  }
}

resource "aws_security_group_rule" "ecs_allow_inbound_traffic" {
  type = "ingress"
  from_port = 0
  to_port = 65535
  protocol = "all"
  cidr_blocks = ["${aws_subnet.ecs_private_subnet.cidr_block}"]
  security_group_id = "${aws_security_group.ecs_access_via_nat.id}"
}

#### subnets
# public subnet NAT gw
resource "aws_subnet" "ecs_public_subnet" {
  cidr_block = "100.0.0.0/28"
  vpc_id = "${aws_vpc.ecs_cluster_vpc.id}"
  availability_zone = "${var.region}b"

  tags {
    Name = "ecs-cluster-public"
    Visibility = "Public"
  }
}

# private subnet
resource "aws_subnet" "ecs_private_subnet" {
  cidr_block = "100.0.1.0/24"
  vpc_id = "${aws_vpc.ecs_cluster_vpc.id}"
  availability_zone = "${var.region}b"

  tags {
    Name = "ecs-cluster-private"
    Visibility = "Private"
  }
}

### NAT
resource "aws_internet_gateway" "ecs_cluster_igw" {
  vpc_id = "${aws_vpc.ecs_cluster_vpc.id}"
  tags {
    Name = "ecs-cluster-igw"
  }
}

# allow internet access to nat
resource "aws_route_table" "public_to_internet" {
  vpc_id = "${aws_vpc.ecs_cluster_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ecs_cluster_igw.id}"
  }

  tags {
    Name = "ecs-public-to-internet"
  }
}
resource "aws_route_table_association" "internet_for_public" {
  route_table_id = "${aws_route_table.public_to_internet.id}"
  subnet_id      = "${aws_subnet.ecs_public_subnet.id}"
}

# Nat gateway
resource "aws_eip" "ecs_eip" {
  tags {
    Name = "ecs-cluster-eip"
  }
}

resource "aws_nat_gateway" "ecs_nat" {
  allocation_id = "${aws_eip.ecs_eip.id}"
  subnet_id = "${aws_subnet.ecs_public_subnet.id}"
}

# allow internet access to cluster nodes through nat
resource "aws_route_table" "ecs_nat_gw" {
  vpc_id = "${aws_vpc.ecs_cluster_vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.ecs_nat.id}"
  }

  tags {
    Name = "ecs-to-internet-thru-nat"
  }
}
resource "aws_route_table_association" "ecs_subnet_to_nat_gw" {
  route_table_id = "${aws_route_table.ecs_nat_gw.id}"
  subnet_id      = "${aws_subnet.ecs_private_subnet.id}"
}

resource "aws_launch_template" "ecs_cluster_lt" {
  name = "ecs-cluster-lt"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 40, #snapshot for AL2 ECS is 30GB
      volume_type = "gp2",
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    name = "jenkins-role"
  }

  image_id = "${var.ecs_ami_id}"
  instance_initiated_shutdown_behavior = "terminate"

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
      # max_price ="${var.spot_price}"
    }
  }

  instance_type = "${var.instance_type}"
  key_name = "${aws_key_pair.jenkins_generated_key.key_name}"

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = ["${aws_security_group.ecs_access_via_nat.id}"]

  tag_specifications {
    resource_type = "instance"
    tags {
      Name = "ecs-cluster-ec2-instance"
    }
  }

  user_data = "${var.user_data}"

  lifecycle {
    # prevent_destroy = true
    ignore_changes = [
      "latest_version",
      "user_data",
      "instance_market_options.spot_options.max_price"
    ]
  }

  depends_on = ["aws_key_pair.jenkins_generated_key"]
}

resource "aws_autoscaling_group" "ecs_cluster_asg" {
  name = "ecs-cluster-asg"
  availability_zones = ["ap-southeast-1b"]
  desired_capacity = 0
  max_size = 2
  min_size = 0
  launch_template = {
    id = "${aws_launch_template.ecs_cluster_lt.id}"
    version = "$$Latest"
  }
  vpc_zone_identifier = ["${aws_subnet.ecs_private_subnet.id}"]

  lifecycle {
    # prevent_destroy = true
    ignore_changes = [
      "desired_capacity"
    ]
  }
}

# create cluster
resource "aws_ecs_cluster" "ecs_medium_cluster" {
    name = "${var.ecs_cluster_name}"
}

resource "aws_ecs_task_definition" "jenkins_slave_sg" {
    count                 = "${var.region == "ap-southeast-1" ? 1 : 0}"
    family                = "ecs-jenkins-slave"
    container_definitions = "${file("task-definitions/ecs-jenkins-slave-sg.json")}"
    requires_compatibilities = ["EC2"]
    network_mode          = "host"
}

resource "aws_ecs_task_definition" "jenkins_slave_ie" {
    count                 = "${var.region == "eu-west-1" ? 1 : 0}"
    family                = "ecs-jenkins-slave"
    container_definitions = "${file("task-definitions/ecs-jenkins-slave-ie.json")}",
    requires_compatibilities = ["EC2"]
    network_mode          = "host"
}

resource "aws_ecs_task_definition" "fargate_slave_sg" {
    count                 = "${var.region == "ap-southeast-1" ? 1 : 0}"
    family                = "fargate-jenkins-slave"
    container_definitions = "${file("task-definitions/fargate-jenkins-slave-sg.json")}"
    cpu                   = 256
    memory                = 512
    execution_role_arn    = "ecsTaskExecutionRole"
    task_role_arn         = "ecsTaskExecutionRole"
    requires_compatibilities = ["FARGATE"]
    network_mode          = "awsvpc"
}

resource "aws_ecs_task_definition" "fargate_slave_ie" {
    count                 = "${var.region == "eu-west-1" ? 1 : 0}"
    family                = "fargate-jenkins-slave"
    container_definitions = "${file("task-definitions/fargate-jenkins-slave-ie.json")}",
    cpu                   = 256
    memory                = 512
    execution_role_arn    = "ecsTaskExecutionRole"
    task_role_arn         = "ecsTaskExecutionRole"
    requires_compatibilities = ["FARGATE"]
    network_mode          = "awsvpc"
}

#
# CloudWatch resources
#
resource "aws_autoscaling_policy" "container_instance_scale_up" {
  name                   = "asgScalingPolicy-${var.ecs_cluster_name}-ClusterScaleUp"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = "${var.scale_up_cooldown_seconds}"
  autoscaling_group_name = "ecs-cluster-asg"
  depends_on             = ["aws_autoscaling_group.ecs_cluster_asg"]
}

resource "aws_autoscaling_policy" "container_instance_scale_down" {
  name                   = "asgScalingPolicy-${var.ecs_cluster_name}-ClusterScaleDown"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = "${var.scale_down_cooldown_seconds}"
  autoscaling_group_name = "ecs-cluster-asg"
  depends_on             = ["aws_autoscaling_group.ecs_cluster_asg"]
}

resource "aws_cloudwatch_metric_alarm" "container_instance_high_cpu" {
  alarm_name          = "alarm-${var.ecs_cluster_name}-ClusterCPUReservationHigh"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "${var.high_cpu_evaluation_periods}"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "${var.high_cpu_period_seconds}"
  statistic           = "Average"
  threshold           = "${var.high_cpu_threshold_percent}"

  dimensions {
    ClusterName = "${var.ecs_cluster_name}"
  }

  alarm_description = "Scale up if CPUReservation is above N% for N duration"
  alarm_actions     = ["${aws_autoscaling_policy.container_instance_scale_up.arn}"]

  depends_on = ["aws_ecs_cluster.ecs_medium_cluster"]
}

resource "aws_cloudwatch_metric_alarm" "container_instance_low_cpu" {
  alarm_name          = "alarm-${var.ecs_cluster_name}-ClusterCPUReservationLow"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "${var.low_cpu_evaluation_periods}"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "${var.low_cpu_period_seconds}"
  statistic           = "Maximum"
  threshold           = "${var.low_cpu_threshold_percent}"

  dimensions {
    ClusterName = "${var.ecs_cluster_name}"
  }

  alarm_description = "Scale down if the CPUReservation is below N% for N duration"
  alarm_actions     = ["${aws_autoscaling_policy.container_instance_scale_down.arn}"]

  depends_on = ["aws_ecs_cluster.ecs_medium_cluster"]
}

resource "aws_cloudwatch_metric_alarm" "container_instance_high_memory" {
  alarm_name          = "alarm-${var.ecs_cluster_name}-ClusterMemoryReservationHigh"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "${var.high_memory_evaluation_periods}"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "${var.high_memory_period_seconds}"
  statistic           = "Maximum"
  threshold           = "${var.high_memory_threshold_percent}"

  dimensions {
    ClusterName = "${var.ecs_cluster_name}"
  }

  alarm_description = "Scale up if the MemoryReservation is above N% for N duration"
  alarm_actions     = ["${aws_autoscaling_policy.container_instance_scale_up.arn}"]

  depends_on = ["aws_ecs_cluster.ecs_medium_cluster"]
}

resource "aws_cloudwatch_metric_alarm" "container_instance_low_memory" {
  alarm_name          = "alarm-${var.ecs_cluster_name}-ClusterMemoryReservationLow"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "${var.low_memory_evaluation_periods}"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "${var.low_memory_period_seconds}"
  statistic           = "Maximum"
  threshold           = "${var.low_memory_threshold_percent}"

  dimensions {
    ClusterName = "${var.ecs_cluster_name}"
  }

  alarm_description = "Scale down if the MemoryReservation is below N% for N duration"
  alarm_actions     = ["${aws_autoscaling_policy.container_instance_scale_down.arn}"]

  depends_on = ["aws_ecs_cluster.ecs_medium_cluster"]
}
