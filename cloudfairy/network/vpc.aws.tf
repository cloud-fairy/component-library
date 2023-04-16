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

resource "aws_eip" "nat" {
  count = 1

  vpc = true
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.1"

  name = var.properties.vpc_name

  cidr = var.properties.cidr_block
  azs  = slice(data.aws_availability_zones.available.names, 0, 1)

  private_subnets = var.properties.enable_public_access ? [replace(var.properties.cidr_block, "/0\\.0/16/", "9.0/24")] : []
  public_subnets  = var.properties.enable_public_access ? [replace(var.properties.cidr_block, "/0\\.0/16/", "10.0/24")] : []

  enable_nat_gateway     = var.properties.enable_public_access
  single_nat_gateway     = var.properties.enable_public_access
  one_nat_gateway_per_az = false
  reuse_nat_ips          = true  
  external_nat_ip_ids    = "${aws_eip.nat.*.id}" 
  enable_dns_hostnames   = true

  tags = {
    Name        = var.properties.vpc_name
    Terraform   = "true"
    Environment = var.project.environment_name
    Project     = var.project.project_name
  }
}

output "cfout" {
  value = {
    name            = var.properties.vpc_name
    cidr            = var.properties.cidr_block
    id              = module.vpc.vpc_id
    route_table_id  = module.vpc.private_route_table_ids[0]
  }
}
