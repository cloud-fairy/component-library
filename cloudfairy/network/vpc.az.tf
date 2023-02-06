variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

locals {
  tenantId       = var.dependency.cloud_provider.tenant_id
  region_name         = var.dependency.cloud_provider.region
  region         = var.dependency.cloud_provider.region
  location         = var.dependency.cloud_provider.region
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  app_range_name = "app-range"
  svc_range_name = "svc-range"
  address_space                   = ["10.151.0.0/16"]
  app_subnet_address_prefixes     = ["10.151.0.0/21"]
  network_name   = "app-vnet"
  env = var.project.environment_name
  vnet_cidr_range = "10.0.0.0/16"
  subnet_prefixes = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  subnet_names = ["infra", "web", "database"]
}


data "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
}

module "network" {
  source              = "Azure/vnet/azurerm"
  version             = "~> 3.0"
  resource_group_name = local.resource_group_name
  vnet_name           = local.network_name
  vnet_location       = local.location
  address_space       = [local.vnet_cidr_range]
  subnet_prefixes     = local.subnet_prefixes
  subnet_names        = local.subnet_names
  nsg_ids             = {}

  tags = {
    environment = local.env
  }
}

output "cfout" {
  value = {
    vpc = {
        name = local.resource_group_name
        /* subnet_ids = {
            for id in (local.subnet_names) : id => module.network.subnet[id].id
        } */
    }
  }
}