# Configuring policy document with permissions for all CloudFairy components
locals {
  policy_name              = "${var.properties.instance_name}-policy"
}

data "aws_iam_policy_document" "ec2" {
    statement {
        actions            = ["ec2:*"]
        resources          = [ module.ec2_instance.arn ]
    }
}

# Creating the policy of the S3 Bucket that was created
module "ec2_iam_policy" {
  source                   = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version                  = "5.18.0"

  name                     = local.policy_name
  path                     = "/"
  description              = "Cloudfairy RDS Full Access"
  tags                     = local.tags

  policy                   = data.aws_iam_policy_document.ec2.json

  depends_on               = [ module.ec2_instance ]
}

# Attaching the S3 policy to the role created with the project
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  policy_arn               = module.ec2_iam_policy.arn
  role                     = var.dependency.base.role_name
}