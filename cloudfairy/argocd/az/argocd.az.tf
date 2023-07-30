data "azurerm_client_config" "current" {}
locals {
  cluster_name = var.dependency.cluster.aks_name
  tags         = var.dependency.base.tags
}


resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argo-cd" {
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "5.41.1"
  values = [
    file("${path.module}/values.yaml")
  ]
}

output "cfout" {
  value = {
    Installed_Operators = "[ argocd ]"
  }
}
