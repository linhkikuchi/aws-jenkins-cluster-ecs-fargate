variable ecs_ami_id {
  default = "ami-0a3f70f0255af1d29"
}

variable instance_type {
  default = "t2.medium"
}

# variable iam_role_instance_profile {}

# variable iam_spot_fleet_role_arn {}

variable "desired_capacity" {
  default = "1"
}

variable "min_size" {
  default = "0"
}

variable "max_size" {
  default = "2"
}

variable key_name {
  default = "jenkins-dev-sg"
}

#variable security_group_id {}

variable spot_price {
  default = "0.05"
}

#variable subnet_ids {}

#variable vpc_id {}

variable user_data {}

variable region {
  default = "ap-southeast-1"
}

variable "autoscaling_group_name" {
  default = "ecs_cluster_asg"
}

variable "ecs_cluster_name" {
  default = "ecs-medium-cluster-sg"
}

variable "health_check_grace_period" {
  default = "600"
}

variable "scale_up_cooldown_seconds" {
  default = "300"
}

variable "scale_down_cooldown_seconds" {
  default = "300"
}

variable "high_cpu_evaluation_periods" {
  default = "2"
}

variable "high_cpu_period_seconds" {
  default = "300"
}

variable "high_cpu_threshold_percent" {
  default = "90"
}

variable "low_cpu_evaluation_periods" {
  default = "2"
}

variable "low_cpu_period_seconds" {
  default = "600"
}

variable "low_cpu_threshold_percent" {
  default = "5"
}

variable "high_memory_evaluation_periods" {
  default = "2"
}

variable "high_memory_period_seconds" {
  default = "300"
}

variable "high_memory_threshold_percent" {
  default = "90"
}

variable "low_memory_evaluation_periods" {
  default = "3"
}

variable "low_memory_period_seconds" {
  default = "600"
}

variable "low_memory_threshold_percent" {
  default = "3"
}
