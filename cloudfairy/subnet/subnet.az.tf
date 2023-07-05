variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}


resource "azurerm_subnet" "subnet" {
  # count = var.properties.subnets_count
  resource_group_name  = var.dependency.cloud_provider.resource_group_name
  virtual_network_name = var.dependency.network.vnet_name
  name                 = var.properties.subnet_name
  address_prefixes     = [replace(var.dependency.network.cidr, "/0\\.0/16/", var.properties.cidr)]
  /* depends_on = [
    var.dependency.network.vnet_id
  ] */
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
    subnet_name      = azurerm_subnet.subnet.name
    subnet_id        = azurerm_subnet.subnet.id
    address_prefixes = [azurerm_subnet.subnet.address_prefixes]
    azurerm_subnet   = [azurerm_subnet.subnet]
  }
}
