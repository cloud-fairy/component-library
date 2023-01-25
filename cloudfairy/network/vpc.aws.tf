variable config {
  type = any
}

variable "dependency" {
  type = any
}

module "vpc" {
  source = "../../modules/aws/vpc"

  name           = var.config.name
  region         = "eu-west-1"
  create_bastion = true
  public_key     = var.dependency.hackinfra_gitlab_secrets.ssh.public
  cidr           = var.config.cidr

  availability_zones = [
    "eu-west-1a",
    "eu-west-1b",
    "eu-west-1c"
  ]

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}

output "cfout" {
  value = {
    vpc_id             = module.vpc.vpc_id
    availability_zones = module.vpc.availability_zones
    cidr               = module.vpc.cidr
    subnets            = {
      private = module.vpc.private_subnets
      public  = module.vpc.public_subnets
    }
    subnet_groups      = {
      database    = module.vpc.database_subnet_group_name
      elasticache = module.vpc.elasticache_subnet_group_name
    }
  }
}
