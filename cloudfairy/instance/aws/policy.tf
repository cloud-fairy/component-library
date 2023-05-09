module "ec2_iam_policy" {
  source            = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version           = "5.18.0"

  name              = "${var.project.project_name}-${var.project.environment_name}-ec2-${var.properties.instance_name}"
  path              = "/"
  description       = "Cloudfairy EC2 Full Access"
  tags              = local.tags

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:*"
      ],
      "Effect": "Allow",
      "Resource": [
                "${module.ec2_instance.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "${module.ec2_instance.arn}"
    },
    {
        "Effect": "Allow",
        "Action": "elasticloadbalancing:*",
        "Resource": "${module.ec2_instance.arn}"
    },
    {
        "Effect": "Allow",
        "Action": "cloudwatch:*",
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": "autoscaling:*",
        "Resource": "${module.ec2_instance.arn}"
    }
  ]
}
EOF
#   policy = <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Action": "ec2:*",
#             "Effect": "Allow",
#             "Resource": "${module.ec2_instance.arn}"
#         },
#         {
#             "Effect": "Allow",
#             "Action": "elasticloadbalancing:*",
#             "Resource": "${module.ec2_instance.arn}"
#         },
#         {
#             "Effect": "Allow",
#             "Action": "cloudwatch:*",
#             "Resource": "*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": "autoscaling:*",
#             "Resource": "${module.ec2_instance.arn}"
#         },
#         {
#             "Effect": "Allow",
#             "Action": "iam:CreateServiceLinkedRole",
#             "Resource": "${module.ec2_instance.arn}",
#             "Condition": {
#                 "StringEquals": {
#                     "iam:AWSServiceName": [
#                         "autoscaling.amazonaws.com",
#                         "ec2scheduled.amazonaws.com",
#                         "elasticloadbalancing.amazonaws.com",
#                         "spot.amazonaws.com",
#                         "spotfleet.amazonaws.com",
#                         "transitgateway.amazonaws.com"
#                     ]
#                 }
#             }
#         }
#     ]
# }
# EOF
}

resource "aws_iam_role_policy_attachment" "example_policy_attachment" {
  policy_arn       = module.ec2_iam_policy.arn
  role             = "${var.project.project_name}_${var.project.environment_name}_admin_role"

  depends_on       = [ module.ec2_instance ]
}