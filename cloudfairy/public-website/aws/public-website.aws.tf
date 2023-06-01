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
  bucketName        = "${var.properties.bucketName}-${local.tags.Project}-${local.tags.Environment}"
  
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
  acl               = "public-read"

  website = {

    index_document  = var.properties.indexPage
    error_document  = var.properties.errorPage
    routing_rules = [{
      condition = {
        key_prefix_equals = "docs/"
      },
      redirect = {
        replace_key_prefix_with = "documents/"
      }
    }]
  }

  versioning        = {
    enabled         = true
  }

  tags              = local.tags  
}


output "cfout" {
  value             = {
    storage_name    = local.bucketName
    policy_arn      = module.bucket_iam_policy.arn
    instructions    = "deployment: aws s3 sync <Source Folder> s3://${local.bucketName}/path-to-folder/"
  }
}
