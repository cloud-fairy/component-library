variable "properties" {
  type = any
}

variable "project" {
  type = any
}

variable "dependency" {
  type    = any
  default = {}
}

locals {
  name                = var.properties.local_name
  env_name            = var.project.environment_name
  bucket_name         = var.properties.bucketName
  resource_group_name = var.project.RESOURCE_GROUP_NAME
  location            = var.project.CLOUD_REGION

  storage_name         = replace("${var.project.environment_name}${var.properties.local_name}", "-", "")
  storage_account_name = "${local.storage_name}stac"
}

resource "azurerm_storage_account" "static_website" {
  name                     = local.storage_account_name
  resource_group_name      = local.resource_group_name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  static_website {
    index_document     = var.properties.indexPage
    error_404_document = var.properties.errorPage
  }
}

# resource "azurerm_storage_container" "static_website_container" {
#   name                  = "$web"
#   storage_account_name  = azurerm_storage_account.static_website.name
#   container_access_type = "blob"
# }
