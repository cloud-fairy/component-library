module "load_balancer_controller" {
  source                           = "DNXLabs/eks-lb-controller/aws"
  version                          = "0.7.0"
  cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
  cluster_name                     = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

module "eks-external-dns" {
  source  = "lablabs/eks-external-dns/aws"
  version = "1.1.1"

  cluster_identity_oidc_issuer 	    = module.eks.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn  = module.eks.oidc_provider_arn

  depends_on = [
    module.eks
  ]
}

# module "cert-manager" {
#   source  = "terraform-iaac/cert-manager/kubernetes"
#   version = "2.5.1"

#   cluster_issuer_email = "mor.danino@tikalk.com"
# }