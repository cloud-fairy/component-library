module "rds_iam_policy" {
  source            = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version           = "5.18.0"
  create_policy     = local.create_db

  name              = "${var.project.project_name}-${var.project.environment_name}-rds-${var.properties.name}"
  path              = "/"
  description       = "Cloudfairy RDS Full Access"
  tags              = local.tags

  policy = <<EOF
{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "rds:*",
                "Resource": ["${module.db.db_instance_arn}"]
            }
        ]
}
EOF

  depends_on       = [ module.db ]
}

resource "aws_iam_role_policy_attachment" "example_policy_attachment" {
  count            = local.create_db ? 1 : 0
  policy_arn       = module.rds_iam_policy.arn
  role             = "${var.project.project_name}_${var.project.environment_name}_admin_role"

  depends_on       = [ module.db ]
}