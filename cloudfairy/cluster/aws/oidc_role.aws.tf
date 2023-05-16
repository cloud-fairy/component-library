provider "external" {
  # Configuration options
}

# Setting a name for the Cluster irsa assuamble role
locals {
  role_name                     = "${var.project.project_name}_${var.project.environment_name}_${var.properties.name}"
  policies                      = split(" ", base64decode(data.external.policies.result.ecoded_doc))
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

  
  role_policy_arns              = local.policies != [""] ? local.policies : []

  oidc_fully_qualified_subjects = ["system:serviceaccount:*:${var.service_account}_${var.project.environment_name}"]

  depends_on                    = [ data.external.policies ]
}