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

module "iam_policy" {
  source            = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version           = "5.18.0"

  name              = "${var.project.project_name}-${var.project.environment_name}-S3-${var.properties.storage_name}"
  path              = "/"
  description       = "Cloudfairy S3 Full Access"
  tags              = local.tags

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*",
        "s3-object-lambda:*"
      ],
      "Effect": "Allow",
      "Resource": "${module.s3_bucket.s3_bucket_arn}"
    }
  ]
}
EOF
}

output "cfout" {
  value = {
    storage_name  = var.properties.storage_name
    acl           = var.properties.acl
  }
}
