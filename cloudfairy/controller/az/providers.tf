provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)

  }
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)
}

/* provider "helm" {
  kubernetes {
    host                             = var.dependency.cluster.host
    cluster_ca_certificate           = base64decode(var.dependency.cluster.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1"
      args        = ["aks", "get-credentials", "--resource-group", var.dependency.cloud_provider.resource_group_name, "--name", local.cluster_name, "--admin"]
      command     = "az"
    }
  }
} */

/* provider "kubectl" {
  host                              = var.dependency.cluster.host
  cluster_ca_certificate            = base64decode(var.dependency.cluster.kube_config.0.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = ["aks", "get-credentials", "--resource-group", var.dependency.cloud_provider.resource_group_name, --name, local.cluster_name, --admin]
    command     = "az"
  }
} */