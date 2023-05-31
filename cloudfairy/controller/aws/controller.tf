locals {
  cluster                         = var.dependency.cluster

  tags = {
    Terraform                     = "true"
    Environment                   = var.project.environment_name
    Project                       = var.project.project_name
    ProjectID                     = var.dependency.cloud_provider.projectId
  }
}

provider "kubernetes" {
  host                   = local.cluster.host
  cluster_ca_certificate = local.cluster.cluster_ca_certificate
  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = ["eks", "get-token", "--cluster-name", local.cluster.name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster.host
    cluster_ca_certificate = local.cluster.cluster_ca_certificate
    token                  = local.cluster.token
  }
}

module "load_balancer_controller" {
  count =  1 

  source                           = "DNXLabs/eks-lb-controller/aws"
  version                          = "0.7.0"
  cluster_identity_oidc_issuer     = local.cluster.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = local.cluster.oidc_provider_arn
  cluster_name                     = local.cluster.name
}

module "eks-external-dns" {
  count            =  1

  source  = "lablabs/eks-external-dns/aws"
  version = "1.1.1"
  irsa_role_name_prefix             = "${local.tags.ProjectID}-${local.tags.Environment}"

  cluster_identity_oidc_issuer 	    = local.cluster.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn  = local.cluster.oidc_provider_arn
  settings = {
      "domainFilters"="{${join(",", var.external_dns_domain_filters)}}"
  }
}

module "cert-manager" {
  count =  0

  source  = "terraform-iaac/cert-manager/kubernetes"
  version = "2.5.1"

  cluster_issuer_email = "mor.danino@tikalk.com"
}

output "cfout" {
  value = {
    Installed_Operators     = "[ load_balancer_controller , eks-external-dns ]"
  }
}