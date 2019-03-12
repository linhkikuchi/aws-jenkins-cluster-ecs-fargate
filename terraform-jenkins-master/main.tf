# echo "user_data = \"$(base64 -i jenkins-master-dev-userdata.sh)\"" > terraform.tfvars
# terraform apply
variable "user_data" {
  description = "script to launch jenkins container and assign elastic IP"
}

variable "ami_id" {
  description = "ami id"
}

variable "key_name" {
  description = "ssh key name"
}

variable "dns_name" {
  description = "dns name of jenkins instance"
}

variable "server_name" {
  description = "server name"
}

variable "region" {
  description = "where to place jenkins"
  default = "ap-southeast-1"
}

variable "zone_id" {
  description = "route53 zone id"
}

variable "jenkins_backup_bucket" {
  description = "bucket to store state file"
}

variable "release_version" {
  description = "release version"
}

provider "aws" {
  region = "${var.region}"
}

variable "jenkins_slave_sg_ip" {
  description = "Jenkins Slave SG"
}

variable "jenkins_slave_ie_ip" {
  description = "Jenkins Slave IE"
}

# Where to store the terraform state file jenkins-launch-template
# init with backup config for flexibility
# terraform init --backend-config="bucket=terraform-state-sg" --backend-config="key=jenkins-launch-template.tfstate" --backend-config="region=ap-southeast-1"
terraform {
  backend "s3" {
    key     = "jenkins-launch-template.tfstate"
    region  = "ap-southeast-1"
  }
}

### vpc
resource "aws_vpc" "jenkins_vpc" {
  cidr_block           = "10.0.0.0/22"
  enable_dns_hostnames = true
  enable_dns_support   =  true
  tags {
    Name = "jenkins-vpc"
  }
}

#security group for jenkins slave, should be in the same group with packer
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-master-sg"
  description = "Jenkins Security Group"
  vpc_id      = "${aws_vpc.jenkins_vpc.id}"

  tags {
    Name = "jenkins-master-sg"
    region = "${var.region}"
  }
}

resource "aws_security_group_rule" "jenkins-ingress-0" {
  description       = "Allows AXIOM IP and DevOps and Jenkins slaves from 443"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [
                      "${var.jenkins_slave_sg_ip}/32",
                      "${var.jenkins_slave_ie_ip}/32",
                      "${aws_eip.jenkins_eip.public_ip}/32"
                      ]
  security_group_id = "${aws_security_group.jenkins_sg.id}"
}

resource "aws_security_group_rule" "jenkins-ingress-1" {
  description       = "Allows AXIOM IP and DevOps from 22"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [
                      "${aws_eip.jenkins_eip.public_ip}/32"
                      ]
  security_group_id = "${aws_security_group.jenkins_sg.id}"
}

resource "aws_security_group_rule" "jenkins-ingress-2" {
  description       = "Allows inbound traffic from jenkins slave port 50000"
  type              = "ingress"
  from_port         = 50000
  to_port           = 50000
  protocol          = "tcp"
  cidr_blocks       = [
                      "${var.jenkins_slave_sg_ip}/32",
                      "${var.jenkins_slave_ie_ip}/32"
                      ]
  security_group_id = "${aws_security_group.jenkins_sg.id}"
}

resource "aws_security_group_rule" "jenkins-egress-3" {
  description       = "Allows outbound traffic from Jenkins to outside world."
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.jenkins_sg.id}"
}

resource "aws_security_group_rule" "jenkins-ingress-4" {
  description       = "Allows inbound traffic from jenkins slave port 8080"
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [
                      "${var.jenkins_slave_sg_ip}/32",
                      "${var.jenkins_slave_ie_ip}/32"
                      ]
  security_group_id = "${aws_security_group.jenkins_sg.id}"
}

# public subnet
resource "aws_subnet" "jenkins_public_subnet" {
  cidr_block = "10.0.0.0/28"
  vpc_id = "${aws_vpc.jenkins_vpc.id}"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true

  tags {
    Name = "jenkins-public-subnet"
    Visibility = "Public"
  }
}

### IGW
resource "aws_internet_gateway" "jenkins_igw" {
  vpc_id = "${aws_vpc.jenkins_vpc.id}"
  tags {
    Name = "jenkins-igw"
  }
}

# allow internet access to jenkins_vpc
resource "aws_route_table" "public_to_internet" {
  vpc_id = "${aws_vpc.jenkins_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.jenkins_igw.id}"
  }

  tags {
    Name = "jenkins-public-to-internet"
  }
}
resource "aws_main_route_table_association" "internet_for_public" {
  vpc_id         = "${aws_vpc.jenkins_vpc.id}"
  route_table_id = "${aws_route_table.public_to_internet.id}"
}

# EIP
resource "aws_eip" "jenkins_eip" {
  tags {
    Name = "jenkins-eip"
  }
}


resource "aws_launch_template" "jenkins" {
  name = "${var.server_name}-lt"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 60,
      volume_type = "gp2",
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    name = "jenkins-role"
  }

  image_id = "${var.ami_id}"
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t2.large"
  key_name = "${var.key_name}"

  monitoring {
    enabled = true
  }

  placement {
    availability_zone = "ap-southeast-1a"
  }

  vpc_security_group_ids = ["${aws_security_group.jenkins_sg.id}"]

  tag_specifications {
    resource_type = "instance"
    tags {
      Name = "${var.dns_name}"
      internal-hostname = "${var.server_name}"
      public-hostname = "${var.server_name}"
      eip = "${aws_eip.jenkins_eip.public_ip}"
      allocation-id = "${aws_eip.jenkins_eip.id}"
      zone-id = "${var.zone_id}"
      data-bucket = "${var.jenkins_backup_bucket}"
      release-version = "${var.release_version}"
    }
  }

  user_data = "${var.user_data}"
}

resource "aws_autoscaling_group" "jenkins" {
  name = "jenkins-asg"
  availability_zones = ["ap-southeast-1a"]
  desired_capacity = 1
  max_size = 2
  min_size = 1
  launch_template = {
    id = "${aws_launch_template.jenkins.id}"
    version = "$$Latest"
  }
  vpc_zone_identifier = ["${aws_subnet.jenkins_public_subnet.id}"]
  depends_on             = ["aws_launch_template.jenkins"]
}
