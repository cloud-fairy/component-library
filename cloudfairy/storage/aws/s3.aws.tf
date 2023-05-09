variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

locals {
  tags = {
    Terraform       = "true"
    Environment     = var.project.environment_name
    Project         = var.project.project_name
  }
}


module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "3.10.1"

  bucket            = var.properties.storage_name
  acl               = var.properties.acl != "private" ? var.properties.acl : null
  block_public_acls = var.properties.acl == "private" ? true : false

  versioning = {
    enabled         = true
  }

  tags              = local.tags  
}


output "cfout" {
  value = {
    storage_name  = var.properties.storage_name
    acl           = var.properties.acl
  }
}
