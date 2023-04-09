variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = var.properties.vpc_name

  cidr = var.properties.cidr_block
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = var.properties.enable_public_access ? ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"] : [""]

  enable_nat_gateway   = var.properties.enable_public_access
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

output "cfout" {
  value = {
    name = var.properties.vpc_name
    cidr = var.properties.cidr_block
    id   = module.vpc.vpc_id
  }
}
