variable "config" {
  type = object({
    privateEndpoint = string
  })
}

variable "dependency" {
  type = object({
    from_module = object({
      connectionName = string
    })
  })
}

output "cfout" {
  value = [
    {
      name = var.config.privateEndpoint
      value = var.dependency.from_module.connectionName
    }
  ]
}

# env {
#   name = "SOURCE"
#   value = "remote"
# }