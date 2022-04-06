variable config {
  type = any
}

variable "dependency" {
  type = any
  // cloud_provider
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.config.vpcName}"
  cidr = "10.0.0.0/16"

  private_subnets = [
    "10.0.1.0/24", 
    "10.0.2.0/24", 
    "10.0.3.0/24"
    "10.0.4.0/24"
    "10.0.5.0/24"
    ]
  
  public_subnets  = [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24"
    "10.0.104.0/24"
    "10.0.105.0/24"
    "10.0.106.0/24"
    ]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Cloudfairy = "True"
  }
}

output "cfout" {
  value = {
    vpc = module.vpc
    vpcId = module.vpc.vpc_id
    vpcName = "vpc-aws"
  }
}