variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

module "network" {
  source              = "Azure/vnet/azurerm"
  version             =  "4.0.0"
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  vnet_location       = var.dependency.cloud_provider.region
  vnet_name           = var.properties.vpc_name
  use_for_each        = var.use_for_each
  # address_space       = var.properties.cidr_block
  # subnet_prefixes     = var.properties.subnet_prefixes
  # private_subnets     = var.properties.enable_public_access ? [replace(var.properties.cidr_block, "/0\\.0/16/", "9.0/24")] : []
  # public_subnets      = var.properties.enable_public_access ? [replace(var.properties.cidr_block, "/0\\.0/16/", "10.0/24")] : []
  # subnet_names        = var.properties.subnet_names
  nsg_ids             = {}

  tags = {
    environment = var.project.environment_name
  }
}

variable "use_for_each" {
  type    = bool
  default = true
}

variable "name" {
  type    = string
  default = ""
}

output "cfout" {
  value = {
    network_name  = var.properties.vpc_name
    # subnet_names  = var.dependency.subnet_names
    /* cidr = {
      apps        = var.properties.subnet_prefixes
    } */
  }
}
