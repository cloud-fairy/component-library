variable "properties" {
  type = any
}
variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

data "azurerm_resource_group" "rg" {
  name = local.resource_group_name
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "aks-${var.project.project_name}-${var.project.environment_name}"
  location            = ar.dependency.cloud_provider.region
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  dns_prefix          = "${var.project.project_name}-${var.project.environment_name}"

  default_node_pool {
    name            = "default"
    /* node_count      = 3 */
    enable_auto_scaling  = true
    max_count            = 3
    min_count            = 1
    vm_size         = "Standard_A2_v2"
    os_disk_size_gb = 30
  }

  service_principal {
    client_id     = "${var.dependency.cloud_provider.client_id}"
    client_secret = "${var.dependency.cloud_provider.client_secret}"
  }

}

output "cfout" {
  value = {
    kubernetes_cluster_name  = local.cluster_name
    env                      = local.env
    region                   = local.region
  }
}