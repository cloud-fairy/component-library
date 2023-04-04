variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}


output "cfout" {
  value = {
    network_name = var.dependency.network.name
    block = var.properties.block
  }
}
