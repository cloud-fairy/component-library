variable "properties" {
  type                    = any
}

variable "dependency" {
  type                    = any
}

variable "project" {
  type                    = any
}

locals {
  bucketName              = "${var.properties.bucketName}-${local.tags.Environment}.${local.tags.Project}"
  zone_id                 = try(data.aws_route53_zone.this.zone_id, null)

  tags                    = {
    Terraform             = "true"
    Environment           = var.project.environment_name
    Project               = var.project.project_name
    ProjectID             = var.dependency.cloud_provider.projectId
  }
}


module "s3_bucket" {
  source                  = "terraform-aws-modules/s3-bucket/aws"
  version                 = "3.10.1"

  bucket                  = local.bucketName
  block_public_acls       = false
  restrict_public_buckets = false
  block_public_policy     = false
  attach_public_policy    = true

  website = {

    index_document        = var.properties.indexPage
    error_document        = var.properties.errorPage
    # routing_rules   = [{
    #   condition = {
    #     key_prefix_equals = "docs/"
    #   },
    #   redirect = {
    #     replace_key_prefix_with = "documents/"
    #   }
    # }]
  }
  attach_policy           = true
  policy                  =     <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::${local.bucketName}/*"
            ]
        }
    ]
}
  EOF

  versioning              = {
    enabled               = true
  }

  tags                    = local.tags  
}

data "aws_route53_zone" "this" {
  name                    = var.dependency.certificate.domain
  private_zone            = false
}

resource "aws_route53_record" "bucket" {
  zone_id                 = local.zone_id
  name                    = "${local.bucketName}.${var.dependency.certificate.domain}"
  type                    = "A"
  ttl                     = 300
  records                 = [module.s3_bucket.s3_bucket_website_endpoint]
}

output "cfout" {
  value                   = {
    storage_name          = local.bucketName
    policy_arn            = module.bucket_iam_policy.arn
    url                   = "http://${aws_route53_record.bucket.name}"
    instructions          = "deployment: aws s3 sync <Source Folder> s3://${local.bucketName}/path-to-folder/"
  }
}
