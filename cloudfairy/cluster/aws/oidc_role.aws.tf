# Setting a name for the Cluster irsa assuamble role
locals {
  role_name                     = "${var.project.project_name}_${var.project.environment_name}_${var.properties.name}"
}   

data "aws_iam_policy" "cloudfairy" {
  name                          = "webserver-policy"
}

###############################
# IAM assumable role for admin
###############################
module "iam_assumable_role_admin" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role                   = true

  role_name                     = local.role_name

  tags                          = local.tags

  provider_url                  = module.eks.cluster_oidc_issuer_url

  role_policy_arns              = [
    #data.aws_iam_policy.cloudfairy.arn
    var.dependency.base.role_arn
  ]

  oidc_fully_qualified_subjects = ["system:serviceaccount:*:${var.service_account}"]
}
