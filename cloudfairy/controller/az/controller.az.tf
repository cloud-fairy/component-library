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

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)

  }
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



data "azurerm_client_config" "current" {}

module "external_dns" {
  source                  = "paul-pfeiffer/external-dns/azurerm"
  version                 = "0.0.5"
  azure_client_id         = var.dependency.cloud_provider.client_id
  azure_object_id         = data.azurerm_client_config.current.object_id # object id of service principal
  azure_client_secret     = var.dependency.cloud_provider.client_secret
  azure_tenant_id         = var.dependency.cloud_provider.tenant_id
  azure_subscription_id   = var.dependency.cloud_provider.subscription_id
  resource_group_name     = var.dependency.cloud_provider.resource_group_name
  dns_provider            = "azure-private-dns" # currently only azure-private-dns supported
  set_permission          = true                # if set to true permission for the service principal are set 
  # automatically. This includes reader permission on the resource 
  # group and private dns zone contributor permission on the private dns zone

  /* domain_filters = [
    var.dependency.cluster.dns_name
  ] */
}

output "cfout" {
  value = {
    Installed_Operators = "[ external_dns ]"
  }
}
