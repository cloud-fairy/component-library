variable "properties" {
  type = any
}

variable "project" {
  type = any
}

locals {
        role_name          = "${var.project.project_name}_${var.project.environment_name}_admin_role"
}

module "admin_role" {
  source                   = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version                  = "5.18.0"

  create_role              = true

  role_name                = local.role_name

  custom_role_trust_policy = data.aws_iam_policy_document.custom_trust_policy.json
}

data "aws_iam_policy_document" "custom_trust_policy" {
  statement {
    effect                 = "Allow"
    actions                = ["sts:AssumeRole"]

    principals {
      type                 = "AWS"
      identifiers          = ["*"]
    }
  }
  statement {
    effect                 = "Deny"
    actions                = ["sts:AssumeRole"]

    principals {
      type                 = "AWS"
      identifiers          = ["*"]
    }

    condition {
        test               = "NotIpAddress"
        variable           = "aws:SourceIp"
        values             = ["213.57.221.168"]
    }

    condition {
        test               = "Bool"
        variable           = "aws:ViaAWSService"
        values             = ["false"]
    }
  }
}

output "cfout" {
  value = {
    name                    = local.role_name
    arn                     = module.admin_role.iam_role_arn
  }
}