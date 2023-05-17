provider "external" {
  # Configuration options
}

# Setting a name for the Cluster irsa assuamble role
locals {
  role_name                     = "${var.project.project_name}_${var.project.environment_name}_${var.properties.name}_irsa_role"
  external_output               = base64decode(data.external.policies.result.ecoded_doc)
  policies                      = local.external_output != "" ? split(" ", local.external_output) : []
  service_account               = "${var.service_account}_${var.project.environment_name}"
}   

data "external" "policies" {
  program                       = ["bash", "${path.module}/get-policies.bash", "${var.dependency.base.role_name}"]
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

  
  role_policy_arns              = local.policies

  oidc_fully_qualified_subjects = ["system:serviceaccount:*:${var.service_account}_${var.project.environment_name}"]

  depends_on                    = [ data.external.policies ]
}

output "irsa_role" {
  value = {
    service_account             = local.service_account
    irs_role_arn                = module.iam_assumable_role_admin.iam_role_arn
  }
}