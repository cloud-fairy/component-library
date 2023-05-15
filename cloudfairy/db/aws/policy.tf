# Configuring policy document with permissions for all CloudFairy components
locals {
  policy_name              = "${var.properties.name}-policy"
}

data "aws_iam_policy_document" "bucket" {
    statement {
        actions            = ["rds:*"]
        resources          = [ module.db.db_instance_arn ]
    }
}

# Creating the policy of the S3 Bucket that was created
module "rds_iam_policy" {
  source                   = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version                  = "5.18.0"

  name                     = local.policy_name
  path                     = "/"
  description              = "Cloudfairy RDS Full Access"
  tags                     = local.tags

  policy                   = data.aws_iam_policy_document.bucket.json

  depends_on               = [ module.db ]
}

# Attaching the S3 policy to the role created with the project
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  policy_arn               = module.rds_iam_policy.arn
  role                     = var.dependency.base.role_name
}