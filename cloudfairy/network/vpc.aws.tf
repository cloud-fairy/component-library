variable "properties" {
  type                      = any
}

variable "dependency" {
  type                      = any
}

variable "project" {
  type                      = any
}

locals {
  vpc_prefix                = "${var.dependency.cloud_provider.projectId}-${var.project.project_name}-${var.project.environment_name}"
  vpc_suffix                = var.properties.vpc_name != "" ? var.properties.vpc_name : "vpc"
  vpc_name                  = "${local.vpc_prefix}-${local.vpc_suffix}"
}

data "aws_availability_zones" "available" {}

resource "aws_eip" "nat" {
  count                     = 1

  vpc                       = true
}

module "vpc" {
  source                    = "terraform-aws-modules/vpc/aws"
  version                   = "4.0.1"

  name                      = local.vpc_name

  cidr                      = var.properties.cidr_block
  azs                       = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets           = var.properties.enable_public_access ? [replace(var.properties.cidr_block, "/0\\.0/16/", "1.0/24"), replace(var.properties.cidr_block, "/0\\.0/16/", "2.0/24")] : []
  public_subnets            = var.properties.enable_public_access ? [replace(var.properties.cidr_block, "/0\\.0/16/", "10.0/24")] : []

  enable_nat_gateway        = var.properties.enable_public_access
  single_nat_gateway        = var.properties.enable_public_access
  one_nat_gateway_per_az    = false
  reuse_nat_ips             = true  
  external_nat_ip_ids       = "${aws_eip.nat.*.id}" 
  enable_dns_hostnames      = true

  tags = {
    Name                    = local.vpc_name
    Terraform               = "true"
    Environment             = var.project.environment_name
    Project                 = var.project.project_name
    ProjectID               = var.dependency.cloud_provider.projectId
  }
}

output "cfout" {
  value = {
    name                    = local.vpc_name
    cidr                    = var.properties.cidr_block
    id                      = module.vpc.vpc_id
    private_route_table_id  = module.vpc.private_route_table_ids[0]
  }
}
