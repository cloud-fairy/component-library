data "aws_availability_zones" "available" {
  state = "available"
}

variable "config" {
  type = any
}
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "cloudfairy-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
    cloudfairy = "true"
  }
}

output "cfout" {
  value = {
    vpc_id = module.vpc.vpc_id,
    subnets = {
      private = module.vpc.private_subnets
      public = module.vpc.public_subnets
    }
  }
}