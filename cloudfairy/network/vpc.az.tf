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
  vpc_suffix                  = "${var.project.project_name}-${var.project.environment_name}-${var.dependency.cloud_provider.projectId}"
  vpc_prefix                  = var.properties.vpc_name != "" ? var.properties.vpc_name : "vpc"
  vpc_name                    = "${local.vpc_prefix}-${local.vpc_suffix}"

  tags = {
    Vnet_Name                 = local.vpc_name
  }
}

resource "azurerm_virtual_network" "network" {
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  location            = var.dependency.cloud_provider.region
  name                = local.vpc_name
  address_space       = ["${var.properties.cidr_block}"]
  tags                = "${merge(var.dependency.base.tags, local.tags)}"
}

resource "azurerm_subnet" "subnet" {
  resource_group_name  = var.dependency.cloud_provider.resource_group_name
  virtual_network_name = local.vpc_name
  name                 = "${local.vpc_name}-subnet"
  address_prefixes     = [cidrsubnet(var.properties.cidr_block, 8, 6)]
  depends_on = [
    azurerm_virtual_network.network
  ]
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
    vnet_id         = azurerm_virtual_network.network.id
    vnet_name       = local.vpc_name
    address_space   = ["${var.properties.cidr_block}"]
    cidr            = var.properties.cidr_block
    subnet_name     = azurerm_subnet.subnet.name
    subnet_id       = azurerm_subnet.subnet.id
    subnet_prefixes = [azurerm_subnet.subnet.address_prefixes]
  }
}
