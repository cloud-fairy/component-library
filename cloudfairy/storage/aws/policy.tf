module "s3_iam_policy" {
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
      "Resource": [
                "${module.s3_bucket.s3_bucket_arn}",
                "${module.s3_bucket.s3_bucket_arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "example_policy_attachment" {
  policy_arn       = module.s3_iam_policy.arn
  role             = "${var.project.project_name}_${var.project.environment_name}_admin_role"

  depends_on       = [ module.s3_bucket ]
}