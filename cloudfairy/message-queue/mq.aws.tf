resource "random_password" "amq_password" {
  length  = 16
  special = false
}

resource "random_string" "username" {
  length      = 16
  special     = false
}


variable "properties" {
  type = any
}

variable "project" {
  type = any
}

variable "dependency" {
  type = any
}

data "aws_vpc" "this" {
  id = var.dependency.network.vpc_id
}


# Security Group to access from network
module "amq_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name                = "amq-sg-${var.project.environment.prefix}-${var.project.environment.name}"
  description         = "AMQ access from within VPC"
  vpc_id              = var.dependency.network.vpc_id
  ingress_cidr_blocks = [data.aws_vpc.this.cidr_block]
  ingress_rules       = ["rabbitmq-4369-tcp", "rabbitmq-5671-tcp"]
}


# Broker

resource "aws_mq_broker" "rabbit_mq_broker" {
  broker_name = "${var.project.environment.prefix}-${var.project.environment.name}-broker"

  engine_type = "RabbitMQ"
  engine_version = "3.9.16"
  storage_type = "ebs"
  host_instance_type = "mq.t3.micro"

  security_groups = [module.amq_sg.security_group_id]
  auto_minor_version_upgrade = true
  subnet_ids = var.dependency.network.subnets.private

  publicly_accessible = false

  user {
    username = random_string.username.result
    password = random_password.amq_password.result
  }
}