data "azurerm_client_config" "current" {}
locals {
  # subnets_count                   =  length(split(",", (jsonencode(data.aws_subnets.private.*.ids[0][*]))))
  # create_cluster                  =  local.subnets_count > 1 ? true : false    # Two subnets required to create EKS Cluster
  cluster_name = var.dependency.cluster.aks_name
  tags         = var.dependency.base.tags
}

data "azurerm_kubernetes_cluster" "credentials" {
  name                = var.dependency.cluster.aks_name
  resource_group_name = var.dependency.cloud_provider.resource_group_name
}

### External-DNS
resource "kubernetes_namespace" "ex-dns" {
  metadata {
    name = "ex-dns"
  }
}
resource "kubernetes_secret" "azure_config_file" {
  metadata {
    name      = "azure-config-file"
    namespace = kubernetes_namespace.ex-dns.metadata[0].name
  }

  data = { "azure.json" = jsonencode({
    tenantId        = var.dependency.cloud_provider.tenant_id
    subscriptionId  = var.dependency.cloud_provider.subscription_id
    resourceGroup   = var.dependency.cloud_provider.resource_group_name
    aadClientId     = var.dependency.cloud_provider.client_id
    aadClientSecret = var.dependency.cloud_provider.client_secret
    })
  }
}

resource "helm_release" "ex-dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  namespace  = kubernetes_namespace.ex-dns.metadata[0].name
  version    = "1.13.0"

  values = [
    file("${path.module}/values-ex-dns.yaml")
  ]

  set {
    name  = "domainFilters[0]"
    value = var.dependency.cluster.public_dns_zone_name
  }
  set {
    name  = "domainFilters[1]"
    value = var.dependency.cluster.private_dns_zone_name
  }
  set {
    name  = "cluster.enabled"
    value = "true"
  }
  set {
    name  = "metrics.enabled"
    value = "true"
  }
  set {
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
    type  = "string"
  }
  set {
    name  = "service.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = var.dependency.cluster.public_dns_zone_name
    type  = "string"
  }
  set {
    name  = "service.annotations.external-dns\\.alpha\\.kubernetes\\.io/ttl"
    value = "5"
    type  = "string"
  }
  set {
    name  = "provider"
    value = "azure"
  }
  set {
    name  = "policy"
    value = "sync"
  }
  set {
    name  = "txtOwnerId"
    value = var.dependency.cloud_provider.resource_group_name
  }
  depends_on = [ kubernetes_secret.azure_config_file ]
}

### Ingress Controller
resource "kubernetes_namespace" "ing-nginx" {
  metadata {
    name = "ing-nginx"
  }
}
resource "helm_release" "ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ing-nginx.metadata[0].name
  version    = "4.7.1"
}
output "cfout" {
  value = {
    Installed_Operators = "[ external_dns, ingress_nginx ]"
  }
}
