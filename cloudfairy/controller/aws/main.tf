provider "kubernetes" {
  host                   = var.dependency.cluster.host
  cluster_ca_certificate = var.dependency.cluster.cluster_ca_certificate
  token                  = var.dependency.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = var.dependency.cluster.host
    cluster_ca_certificate = var.dependency.cluster.cluster_ca_certificate
    token                  = var.dependency.cluster.token
  }
}

module "load_balancer_controller" {
  count = var.properties.name == "load-balancer" ? 1 : 0

  source                           = "DNXLabs/eks-lb-controller/aws"
  version                          = "0.7.0"
  cluster_identity_oidc_issuer     = var.dependency.cluster.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = var.dependency.cluster.oidc_provider_arn
  cluster_name                     = var.dependency.cluster.name
}

module "eks-external-dns" {
  count = var.properties.name == "external-dns" ? 1 : 0

  source  = "lablabs/eks-external-dns/aws"
  version = "1.1.1"

  cluster_identity_oidc_issuer 	    = var.dependency.cluster.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn  = var.dependency.cluster.oidc_provider_arn
  settings = {
      "domainFilters"="{${join(",", var.external_dns_domain_filters)}}"
  }
}

module "cert-manager" {
  count = var.properties.name == "cert-manager" ? 1 : 0

  source  = "terraform-iaac/cert-manager/kubernetes"
  version = "2.5.1"

  cluster_issuer_email = "mor.danino@tikalk.com"
}