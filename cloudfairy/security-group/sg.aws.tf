variable "properties" {
  type                  = any
}

variable "dependency" {
  type                  = any
}

variable "project" {
  type                  = any
}

module "security_group" {
  source                = "terraform-aws-modules/security-group/aws"
  version               = "4.17.1"

  name                  = var.properties.sg_name
  vpc_id                = var.dependency.network.id
 
  ingress_rules         = [ var.properties.rule ]
  ingress_cidr_blocks   = [ var.properties.block ]

  egress_rules          = [ "all-all" ]

  tags                  = {
    Terraform           = "true"
    Environment         = var.project.environment_name
    Project             = var.project.project_name
    ProjectID           = var.dependency.cloud_provider.projectId
  }
}

output "cfout" {
  value                = {
    name               = var.properties.sg_name
    block              = var.properties.block
    security_group_id  = module.security_group.security_group_id
  }
}