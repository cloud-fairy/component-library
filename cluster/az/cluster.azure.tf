variable "properties" {
  type = any
}

variable "project" {
  type = any
}

locals {
  resource_group_name = var.project.RESOURCE_GROUP_NAME
  cluster_name        = lower("${var.project.environment_name}-${var.project.project_name}")
  environment_name    = var.project.environment_name
  location            = var.project.CLOUD_REGION
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = local.cluster_name
  location            = local.location
  resource_group_name = local.resource_group_name
  dns_prefix          = local.cluster_name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    "cloudfairy"  = "true"
    "environment" = var.project.environment_name
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "${local.environment_name}${replace(local.cluster_name, "-", "")}"
  resource_group_name = local.resource_group_name
  location            = local.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_role_assignment" "kubernetes_container_registry" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}


output "cfout" {
  sensitive = true
  value = {
    hostname               = azurerm_kubernetes_cluster.cluster.kube_config.0.host
    client_certificate     = azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate
    cluster_ca_certificate = azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate
    kube_config            = azurerm_kubernetes_cluster.cluster.kube_config
    container_registry_url = azurerm_container_registry.acr.login_server
  }
}
