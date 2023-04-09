variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

data "aws_ami" "aws_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  count = 1

  name =  var.properties.ec2_name

  ami                    = data.aws_ami.aws_linux.id
  instance_type          = "t2.micro"
  monitoring             = true
  vpc_security_group_ids = [var.dependency.sg.security_group_id]
  subnet_id              = var.dependency.subnet.subnet_id

  tags = {
    Terraform   = "true"
    Environment = project  #.locals.environment_name
  }
}

output "cfout" {
  value = {
    instance_name   = var.properties.ec2_name
    ec2_id          = module.ec2_instance.id
    public_ip       = module.ec2_instance.public_ip
  }
}