variable "properties" {
  type                     = any
}

variable "project" {
  type                     = any
}

locals {
        role_name          = "${var.project.project_name}_${var.project.environment_name}_admin_role"
        policy_name        = "${var.project.project_name}_${var.project.environment_name}_admin_policy"
        tags = {
          Terraform            = "true"
          Environment          = var.project.environment_name
          Project              = var.project.project_name
        }
}

# Creating a role with no policies
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
      identifiers          = ["*"]
    }
  }
}

# Configuring policy document with permissions for all CloudFairy components
data "aws_iam_policy_document" "admin" {
    statement {
        actions            = ["ec2:Describe*"]
        resources          = [ "*" ]
        condition {
          test             = "StringEquals"
          variable         = "aws:PrincipalTag/Environment"
          values           = ["${var.project.environment_name}"]
        }
        condition {
          test             = "StringEquals"
          variable         = "aws:PrincipalTag/Project"
          values           = ["${var.project.project_name}"]
        }
    }
    statement {
        actions            = ["ec2:*"]
        resources          = [ "*" ]
        condition {
          test             = "StringEquals"
          variable         = "aws:PrincipalTag/Environment"
          values           = ["${var.project.environment_name}"]
        }
        condition {
          test             = "StringEquals"
          variable         = "aws:PrincipalTag/Project"
          values           = ["${var.project.project_name}"]
        }
    }
    statement {
        actions            = ["rds:*"]
        resources          = [ "*" ]
        condition {
          test             = "StringEquals"
          variable         = "aws:PrincipalTag/Environment"
          values           = ["${var.project.environment_name}"]
        }
        condition {
          test             = "StringEquals"
          variable         = "aws:PrincipalTag/Project"
          values           = ["${var.project.project_name}"]
        }
    }
    statement {
        actions            = ["s3:*","s3-object-lambda:*"]
        resources          = [ "*" ]
        condition {
          test             = "StringEquals"
          variable         = "aws:PrincipalTag/Environment"
          values           = ["${var.project.environment_name}"]
        }
        condition {
          test             = "StringEquals"
          variable         = "aws:PrincipalTag/Project"
          values           = ["${var.project.project_name}"]
        }
    }
}

# Creating the policy of the Admin Role
module "adminrole_iam_policy" {
  source                   = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version                  = "5.18.0"

  name                     = local.policy_name
  path                     = "/"
  description              = "Cloudfairy Full Access"
  tags                     = local.tags

  policy                   = data.aws_iam_policy_document.admin.json
}

# Attaching the policy to the role
resource "aws_iam_role_policy_attachment" "example_policy_attachment" {
  policy_arn               = module.adminrole_iam_policy.arn
  role                     = local.role_name
}

output "cfout" {
  value = {
    name                    = local.role_name
    arn                     = module.admin_role.iam_role_arn
  }
}