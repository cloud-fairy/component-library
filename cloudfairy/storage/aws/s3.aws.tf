variable "properties" {
  type              = any
}

variable "dependency" {
  type              = any
}

variable "project" {
  type              = any
}

locals {
  bucketName        = "${var.properties.storage_name}-${local.tags.Project}-${local.tags.Environment}"
  tags = {
    Terraform       = "true"
    Environment     = var.project.environment_name
    Project         = var.project.project_name
    ProjectID       = var.dependency.cloud_provider.projectId
  }
}


module "s3_bucket" {
  source            = "terraform-aws-modules/s3-bucket/aws"
  version           = "3.10.1"

  bucket            = local.bucketName
  acl               = var.properties.acl != "private" ? var.properties.acl : null
  block_public_acls = var.properties.acl == "private" ? true : false

  versioning        = {
    enabled         = true
  }

  tags              = local.tags  
}


output "cfout" {
  value             = {
    storage_name    = local.bucketName
    acl             = var.properties.acl
    policy_arn      = module.bucket_iam_policy.arn
  }
}
