variable "properties" {
  type = any
}
variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = var.properties.name
  location            = var.dependency.cloud_provider.region
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  dns_prefix          = "${var.project.project_name}-${var.project.environment_name}"
  sku_tier            = "Standard"

  default_node_pool {
    name                = "default"
    node_count          = 3
    enable_auto_scaling = true
    max_count           = 3
    min_count           = 1
    vm_size             = "Standard_A2_v2"
    os_disk_size_gb     = 30
  }

  service_principal {
    client_id     = var.dependency.cloud_provider.client_id
    client_secret = var.dependency.cloud_provider.client_secret
  }
  role_based_access_control {
    enabled = true
  }
}

resource "azurerm_public_ip" "pubIP" {
  name                = "pub-ip"
  location            = var.dependency.cloud_provider.region
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  allocation_method   = "Static"
}

output "cfout" {
  value = {
    kubernetes_cluster_name = var.properties.name
    env                     = var.project.environment_name
    region                  = var.dependency.cloud_provider.region
  }
}
