variable "dependency" {
  type = any
}
variable "properties" {
  type = any
}
variable "project" {
  type = any
}

locals {
  cluster = var.dependency.from_module
}

output "cfout" {
  value = {
    cluster = local.cluster
    subdomain = var.properties.subdomain
  }
}