variable "properties" {
  type = any
}

output "cfout" {
  value = {
    tenant_id = var.properties.tenant_id
    region    = var.properties.region
    resource_group_name = var.properties.resource_group_name
    type      = "az"
  }
}

output "template" {
  value = <<EOF
provider "azurerm" {
  tenant_id       = "${var.properties.tenant_id}"
  subscription_id = "${var.properties.subscription_id}"
  client_id       = "${var.properties.client_id}"
  client_secret   = "${var.properties.client_secret}"
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
EOF
}
