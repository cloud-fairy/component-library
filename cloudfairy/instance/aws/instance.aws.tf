variable "properties" {
  type                   = any
}

variable "dependency" {
  type                   = any
}

variable "project" {
  type                   = any
}

locals {
  tags = {
    Terraform            = "true"
    Environment          = var.project.environment_name
    Project              = var.project.project_name
  }
}

data "aws_ami" "aws_linux" {
  most_recent            = true

  filter {
    name                 = "name"
    values               = ["al2023-ami-2023*"]
  }

  filter {
    name                 = "virtualization-type"
    values               = ["hvm"]
  }
}

module "ec2_instance" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 3.0"

  name                   =  var.properties.instance_name

  ami                    = data.aws_ami.aws_linux.id
  instance_type          = "t2.micro"
  monitoring             = true
  vpc_security_group_ids = [var.dependency.sg.security_group_id]
  subnet_id              = var.dependency.subnet.subnet_id

  tags                   = local.tags
}

output "cfout" {
  value = {
    instance_name        = var.properties.instance_name
    instance_id          = module.ec2_instance.id
    public_ip            = module.ec2_instance.public_ip
  }
}