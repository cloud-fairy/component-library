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
  bucketName              = "${var.properties.bucketName}-${local.tags.Environment}.${local.tags.Project}.${var.dependency.certificate.zone_name}"
  tags                    = var.dependency.base.tags
  cf_component_name       = try(var.properties.local_name, "Cloudfairy Public Website")
}

# Creating the bucket to host the website files
module "s3_bucket" {
  source                  = "terraform-aws-modules/s3-bucket/aws"
  version                 = "3.10.1"

  bucket                  = local.bucketName
  acl                     = "private"

  versioning               = {
    enabled                = true
  }

  tags                     = local.tags  
}

# Redirecting Alias record from Bucket name to Cloudfront
resource "aws_route53_record" "bucket" {
  zone_id                  = var.dependency.certificate.zone_id
  name                     = local.bucketName
  type                     = "A"
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

output "cfout" {
  value                    = {
    storage_name           = local.bucketName
    policy_arn             = module.bucket_iam_policy.arn
    url                    = "http://${aws_route53_record.bucket.name}"
    regional               = module.s3_bucket.s3_bucket_bucket_regional_domain_name
    instructions           = "deployment: aws s3 sync <Source Folder> s3://${local.bucketName}/path-to-folder/"
    documentation = <<EOF
# ${local.cf_component_name} (http://${aws_route53_record.bucket.name} Public website)

Storage Name: ${local.bucketName}

Public URL: http://${aws_route53_record.bucket.name}

## Deployment
```bash
aws s3 sync <Source Folder> s3://${local.bucketName}
```

EOF

  }
}
