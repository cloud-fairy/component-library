variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}



resource "azurerm_virtual_network" "network" {
  resource_group_name = var.dependency.cloud_provider.resource_group_name
  location            = var.dependency.cloud_provider.region
  name                = var.properties.vpc_name
  address_space       = ["${var.properties.cidr_block}"]
}

locals {
  cdir_oct1 = split(".", var.properties.cidr_block)[0]
  cdir_oct2 = split(".", var.properties.cidr_block)[1]
}

resource "azurerm_subnet" "subnet" {
  count = var.properties.subnets_count
  resource_group_name  = var.dependency.cloud_provider.resource_group_name
  virtual_network_name = var.properties.vpc_name
  name                 = "subnet_${count.index}"
  address_prefixes     = ["${local.cdir_oct1}.${local.cdir_oct2}.${count.index}.0/24"]
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
    vnet_name       = var.properties.vpc_name
    address_space   = ["${var.properties.cidr_block}"]
    subnet_names    = [azurerm_subnet.subnet.*.name]
    subnet_prefixes = [azurerm_subnet.subnet.*.address_prefixes]
  }
}
