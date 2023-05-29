variable properties {
  type                     = any
}

variable "dependency" {
  type                     = any
}

variable "project" {
  type                     = any
}

locals {
  role_name                = "${var.project.project_name}_${var.project.environment_name}_${var.dependency.cloud_provider.projectId}_admin_role"
  tags                     = {
    Terraform              = "true"
    Environment            = var.project.environment_name
    Project                = var.project.project_name
    ProjectID              = var.dependency.cloud_provider.projectId
  }
}

module "admin_role" {
  source                   = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version                  = "5.18.0"

  create_role              = true

  role_name                = local.role_name
  tags                     = local.tags

  custom_role_trust_policy = data.aws_iam_policy_document.custom_trust_policy.json
}

data "aws_iam_policy_document" "custom_trust_policy" {
  statement {
    effect                 = "Allow"
    actions                = ["sts:AssumeRole"]

    principals {
      type                 = "AWS"
      identifiers          = ["557680788250"]
    }
    condition {
      test                 = "StringEquals"
      variable             = "aws:PrincipalTag/Environment"
      values               = [ var.project.environment_name ]
    }
    condition {
      test                 = "StringEquals"
      variable             = "aws:PrincipalTag/Project"
      values               = [ var.project.project_name ]
    }
    condition {
      test                 = "StringEquals"
      variable             = "aws:PrincipalTag/ProjectID"
      values               = [ var.dependency.cloud_provider.projectId ]
    }
  }
}

output "cfout" {
  value                    = {
    role_arn               = module.admin_role.iam_role_arn
    role_name              = local.role_name
  }
}