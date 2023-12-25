variable "properties" {
  type = any

}

variable "project" {
  type = any

}

variable "dependency" {
  type = any
}

provider "kubernetes" {
  insecure    = true
  config_path = var.dependency.cloudfairy_cluster.kubeconfig_path # "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = var.dependency.cloudfairy_cluster.kubeconfig_path # "~/.kube/config"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.24.1"
  namespace  = kubernetes_namespace.argocd.metadata.0.name
  depends_on = [
    kubernetes_namespace.argocd
  ]
}


output "cfout" {
  value = {}
}
