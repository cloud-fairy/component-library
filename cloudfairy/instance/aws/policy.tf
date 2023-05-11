data "aws_iam_policy_document" "ec2" {
    statement {
        actions   = ["ec2:Describe*"]
        resources = [ "*" ]
        condition {
          test     = "StringEquals"
          variable = "aws:PrincipalTag/Environment"
          values = ["${var.project.environment_name}"]
        }
        condition {
          test     = "StringEquals"
          variable = "aws:PrincipalTag/Project"
          values = ["${var.project.project_name}"]
        }
    }
    statement {
        actions   = ["ec2:*"]
        resources = [ "*" ]
        condition {
          test     = "StringEquals"
          variable = "aws:PrincipalTag/Environment"
          values = ["${var.project.environment_name}"]
        }
        condition {
          test     = "StringEquals"
          variable = "aws:PrincipalTag/Project"
          values = ["${var.project.project_name}"]
        }
    }
}
module "ec2_iam_policy" {
  source            = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version           = "5.18.0"

  name              = "${var.project.project_name}-${var.project.environment_name}-ec2-${var.properties.instance_name}"
  path              = "/"
  description       = "Cloudfairy EC2 Full Access"
  tags              = local.tags

  policy            = data.aws_iam_policy_document.ec2.json
}

resource "aws_iam_role_policy_attachment" "example_policy_attachment" {
  policy_arn       = module.ec2_iam_policy.arn
  role             = "${var.project.project_name}_${var.project.environment_name}_admin_role"

  depends_on       = [ module.ec2_instance ]
}