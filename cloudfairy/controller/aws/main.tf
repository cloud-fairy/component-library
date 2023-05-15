locals {
  cluster = var.connector.controller_to_cluster_connector[0].cluster
}

provider "kubernetes" {
  host                   = local.cluster.host
  cluster_ca_certificate = local.cluster.cluster_ca_certificate
  token                  = local.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = local.cluster.host
    cluster_ca_certificate = local.cluster.cluster_ca_certificate
    token                  = local.cluster.token
  }
}

module "load_balancer_controller" {
  count = var.properties.name == "load-balancer" ? 1 : 0

  source                           = "DNXLabs/eks-lb-controller/aws"
  version                          = "0.7.0"
  cluster_identity_oidc_issuer     = local.cluster.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = local.cluster.oidc_provider_arn
  cluster_name                     = local.cluster.name
}

module "eks-external-dns" {
  count = var.properties.name == "external-dns" ? 1 : 0

  source  = "lablabs/eks-external-dns/aws"
  version = "1.1.1"

  cluster_identity_oidc_issuer 	    = local.cluster.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn  = local.cluster.oidc_provider_arn
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