# Configuring policy document with permissions for all CloudFairy components
locals {
  policy_name              = "${var.properties.storage_name}-${local.tags.Project}-${local.tags.Environment}"
}

data "aws_iam_policy_document" "bucket" {
    statement {
        actions            = ["s3:*","s3-object-lambda:*"]
        resources          = [ module.s3_bucket.s3_bucket_arn, "${module.s3_bucket.s3_bucket_arn}/*"]
    }
}

# Creating the policy of the S3 Bucket that was created
module "bucket_iam_policy" {
  source                   = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version                  = "5.18.0"

  name                     = local.policy_name
  path                     = "/"
  description              = "Cloudfairy S3 bucket Full Access"
  tags                     = local.tags

  policy                   = data.aws_iam_policy_document.bucket.json

  depends_on               = [ module.s3_bucket ]
}

# Attaching the S3 policy to the role created with the project
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  policy_arn               = module.bucket_iam_policy.arn
  role                     = var.dependency.base.role_name
}