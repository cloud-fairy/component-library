variable "properties" {
  type = any
}
variable "dependency" {
  type = any
}

variable "project" {
  type = any
}
variable "private_dns" {
  type    = any
  default = "true"
}

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.20.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.1"
    }
  }
}

locals {
  tags = var.dependency.base.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                                = var.properties.name
  resource_group_name                 = var.dependency.cloud_provider.resource_group_name
  location                            = var.dependency.cloud_provider.region
  dns_prefix                          = "${var.project.project_name}-${var.project.environment_name}"
  sku_tier                            = "Standard"
  private_cluster_enabled             = var.properties.enable_public_access == "true" ? "false" : "true"
  private_cluster_public_fqdn_enabled = true

  default_node_pool {
    name                = "default"
    node_count          = 1
    enable_auto_scaling = false
    min_count           = null # 1
    max_count           = null # 3
    vm_size             = "Standard_A2_v2"
    os_disk_size_gb     = 30
  }

  service_principal {
    client_id     = var.dependency.cloud_provider.client_id
    client_secret = var.dependency.cloud_provider.client_secret
  }
  lifecycle {
    ignore_changes = [private_cluster_public_fqdn_enabled]
  }
}

resource "azurerm_public_ip" "pub_ip" {
  name                = "pub-ip"
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  location            = var.dependency.cloud_provider.region
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_public_ip_prefix" "nat_prefix" {
  name                = "nat-gateway-publicIPPrefix"
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  location            = var.dependency.cloud_provider.region
  prefix_length       = 30
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_nat_gateway" "gw_aks" {
  name                    = "nat-Gateway"
  resource_group_name     = var.dependency.cloud_provider.resource_group_name
  location                = var.dependency.cloud_provider.region
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
  zones                   = ["1"]
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "nat-ips" {
  nat_gateway_id      = azurerm_nat_gateway.gw_aks.id
  public_ip_prefix_id = azurerm_public_ip_prefix.nat_prefix.id
}

resource "azurerm_subnet_nat_gateway_association" "sn_nat_gw" {
  subnet_id      = var.dependency.subnet.subnet_id
  nat_gateway_id = azurerm_nat_gateway.gw_aks.id
}

resource "azurerm_nat_gateway_public_ip_association" "pub_ip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.gw_aks.id
  public_ip_address_id = azurerm_public_ip.pub_ip.id
}

resource "azurerm_dns_zone" "pub_dns_zone" {
  count               = var.private_dns == "false" ? 1 : 0
  name                = "${local.tags.Environment}.${local.tags.Project}"
  resource_group_name = var.dependency.cloud_provider.resource_group_name
}
resource "azurerm_private_dns_zone" "prv_dns_zone" {
  count               = var.private_dns == "true" ? 1 : 0
  name                = "${local.tags.Environment}.${local.tags.Project}"
  resource_group_name = var.dependency.cloud_provider.resource_group_name
}

data "azurerm_resources" "aks_vnet" {
  resource_group_name = "MC_${var.dependency.cloud_provider.resource_group_name}_${azurerm_kubernetes_cluster.aks.name}_${azurerm_kubernetes_cluster.aks.location}"
  type                = "Microsoft.Network/virtualNetworks"
  depends_on          = [azurerm_kubernetes_cluster.aks]
}
resource "azurerm_private_dns_zone_virtual_network_link" "priv_dns_link" {
  count               = var.private_dns == "true" ? 1 : 0
  name                = "priv-zone-vnet-link"
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.prv_dns_zone[count.index].name
  registration_enabled = true
  # virtual_network_id   = "/subscriptions/40a800ae-b686-43e3-8599-61b3dbbf57d9/resourceGroups/MC_tikal-rg_aks_eastus/providers/Microsoft.Network/virtualNetworks/aks-vnet-78383438"
  virtual_network_id    = data.azurerm_resources.aks_vnet.resources[0].id
}


output "cfout" {
  value = {
    aks_name                            = var.properties.name
    env                                 = var.project.environment_name
    region                              = var.dependency.cloud_provider.region
    location                            = azurerm_kubernetes_cluster.aks.location
    gateway_ips                         = azurerm_public_ip_prefix.nat_prefix.ip_prefix
    pub_ip                              = azurerm_public_ip.pub_ip.ip_address
    enable_public_access                = var.properties.enable_public_access
    private_cluster_enabled             = azurerm_kubernetes_cluster.aks.private_cluster_enabled
    private_cluster_public_fqdn_enabled = azurerm_kubernetes_cluster.aks.private_cluster_public_fqdn_enabled
    public_dns_zone_name                = var.private_dns == "false" ? azurerm_dns_zone.pub_dns_zone[0].name : null
    private_dns_zone_name               = var.private_dns == "true" ? azurerm_private_dns_zone.prv_dns_zone[0].name : null
    private_dns                         = var.private_dns
    MC_aks                              = [data.azurerm_resources.aks_vnet]
    MC_vnet_id                          = data.azurerm_resources.aks_vnet.resources[0].id
    tags                                = local.tags
  }
}
