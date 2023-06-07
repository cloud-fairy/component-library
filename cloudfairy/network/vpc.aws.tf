variable "properties" {
  type                        = any
}

variable "dependency" {
  type                        = any
}

variable "project" {
  type                        = any
}

locals {
  vpc_suffix                  = "${var.dependency.cloud_provider.projectId}-${var.project.project_name}-${var.project.environment_name}"
  vpc_prefix                  = var.properties.vpc_name != "" ? var.properties.vpc_name : "vpc"
  vpc_name                    = "${local.vpc_prefix}-${local.vpc_suffix}"

  tags = {
    Name                      = local.vpc_name
    Terraform                 = "true"
    Environment               = var.project.environment_name
    Project                   = var.project.project_name
    ProjectID                 = var.dependency.cloud_provider.projectId
  }
}

data "aws_availability_zones" "available" {}

resource "aws_eip" "nat" {
  count                       = 1

  domain                      = "vpc"

  tags                        = local.tags
}

module "vpc" {
  source                      = "terraform-aws-modules/vpc/aws"
  version                     = "4.0.1"

  name                        = local.vpc_name

  cidr                        = var.properties.cidr_block
  azs                         = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets             = [
    cidrsubnet(var.properties.cidr_block, 8, 1),
    cidrsubnet(var.properties.cidr_block, 8, 2),
  ]
  private_subnet_tags         = {
    type                      = "Private"
    "kubernetes.io/role/internal-elb"  = "1"
  }

  public_subnets              = [
    cidrsubnet(var.properties.cidr_block, 8, 9),
    cidrsubnet(var.properties.cidr_block, 8, 11),
  ]
  public_subnet_tags          = {
    type                      = "Public"
    "kubernetes.io/role/elb"  = "1"
  }

  enable_nat_gateway          = var.properties.enable_public_access
  single_nat_gateway          = var.properties.enable_public_access
  one_nat_gateway_per_az      = false
  reuse_nat_ips               = true  
  external_nat_ip_ids         = "${aws_eip.nat.*.id}" 
  enable_dns_hostnames        = true

  tags                        = local.tags
}

output "cfout" {
  value = {
    name                      = local.vpc_name
    cidr                      = var.properties.cidr_block
    id                        = module.vpc.vpc_id
    private_route_table_id    = module.vpc.private_route_table_ids[0]
  }
}
