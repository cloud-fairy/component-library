variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}


module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket            = var.properties.storage_name
  acl               = var.properties.acl
  block_public_acls = var.properties.acl == "private" ? true : false

  versioning = {
    enabled = true
  }

  tags = {
    Terraform   = "true"
    Environment = var.project.environment_name
    Project     = var.project.project_name
  }
}

output "cfout" {
  value = {
    storage_name = var.properties.storage_name
    priave       = var.properties.acl
  }
}
