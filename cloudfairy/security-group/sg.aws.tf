variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name   = var.properties.sg_name
  vpc_id = var.dependency.network.id
 
  ingress_rules         = [var.properties.rule]
  ingress_cidr_blocks   = [var.properties.block]

  egress_rules          = [ "all-all" ]
}

output "cfout" {
  value = {
    network_name        = var.dependency.network.name
    block               = var.properties.block
    security_group_id   = module.security_group.security_group_id
  }
}