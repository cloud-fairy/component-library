variable "properties" {
  type = any
}

variable "properties" {
  type = any
}

module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc"

  name = var.properties.name
  cidr = var.properties.cidr

  azs = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
  enable_nat_gateway = true
  enable_vpn_gateway = true
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  tags = {
    Terraform   = "true"
    Environment = "dev"
    cloudfairy  = "true"
  }
}

output "cfout" {
  value = {
    vpc_id             = module.vpc.vpc_id
    availability_zones = module.vpc.azs
    cidr               = module.vpc.vpc_cidr_block
    subnets = {
      private = module.vpc.private_subnets
      public  = module.vpc.public_subnets
    }
  }
}
