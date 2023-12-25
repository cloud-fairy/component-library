variable "properties" {
  type = any
}

variable "project" {
  type = any
}

output "cfout" {
  value = {
    tenant_id           = var.project.TENANT_ID
    subscription_id     = var.project.SUBSCRIPTION_ID
    resource_group_name = var.project.RESOURCE_GROUP_NAME
    type                = "az"
  }
}

output "template" {
  value = <<EOF
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
EOF
}
