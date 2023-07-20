variable "properties" {
  type = any
}
variable "dependency" {
  type = any
}

variable "project" {
  type = any
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

resource "azurerm_private_dns_zone" "prv_dns_zone" {
  name                = "tikal.org"
  resource_group_name = var.dependency.cloud_provider.resource_group_name
}

resource "azurerm_dns_zone" "pub_dns_zone" {
  name                = "${local.tags.Environment}.${local.tags.Project}.tikalk.dev"
  resource_group_name = var.dependency.cloud_provider.resource_group_name
}

/* resource "azurerm_private_dns_zone_virtual_network_link" "priv_dns_link" {
  name                = "priv-zone-vnet-link"
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  # private_dns_zone_id = azurerm_private_dns_zone.prv_dns_zone.id
  private_dns_zone_name = azurerm_private_dns_zone.prv_dns_zone.name
  virtual_network_id    = var.dependency.network.vnet_id
} */

/* provider "helm" {
  kubernetes {
    host                             = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate           = base64decode(data.azurerm_kubernetes_cluster.eks.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubectl" {
  host                              = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate            = base64decode(data.aws_eks_cluster.eks.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    command     = "aws"
  }
}

resource "null_resource" "kubectl" {
    triggers = {
      always_run = timestamp()
    }
    provisioner "local-exec" {
        command = "aws eks --region ${var.dependency.cloud_provider.region} update-kubeconfig --name ${data.aws_eks_cluster.eks.name}"
    }
} */

/* data "azurerm_resources" "resources" {
  resource_group_name = "MC_tikal-rg_aks_eastus"
} */

/* data "azurerm_resource_group" "aks_mc_rg" {
  depends_on = [azurerm_kubernetes_cluster.aks]
  name = azurerm_kubernetes_cluster.aks.node_resource_group
} */

output "cfout" {
  value = {
    aks_name                            = var.properties.name
    env                                 = var.project.environment_name
    region                              = var.dependency.cloud_provider.region
    gateway_ips                         = azurerm_public_ip_prefix.nat_prefix.ip_prefix
    pub_ip                              = azurerm_public_ip.pub_ip.ip_address
    tags                                = local.tags
    enable_public_access                = var.properties.enable_public_access
    private_cluster_enabled             = azurerm_kubernetes_cluster.aks.private_cluster_enabled
    private_cluster_public_fqdn_enabled = azurerm_kubernetes_cluster.aks.private_cluster_public_fqdn_enabled
    public_dns_zone_name                = azurerm_dns_zone.pub_dns_zone.name
    private_dns_zone_name               = azurerm_private_dns_zone.prv_dns_zone.name
    # private_dns_zone_id                  = azurerm_private_dns_zone.prv_dns_zone.id
    # aks_piblic_ip                     = azurerm_kubernetes_cluster.aks.network_profile[*]
    # aks                               = azurerm_kubernetes_cluster.aks.*
    # aks_mc                            = data.azurerm_resources.resources.*
    # aks_mc                            = azurerm_resource_group.aks_mc_rg
  }
}

/* output "aks_piblic_ip" {
  value = azurerm_kubernetes_cluster.aks.*
} */