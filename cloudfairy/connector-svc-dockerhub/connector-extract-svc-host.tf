variable "properties" {
  type                 = any
}

variable "dependency" {
  type                 = object({
    from_module        = any
  })
}

locals {
    service_hostname   = var.dependency.from_module.service_hostname
    service_port       = tostring(var.dependency.from_module.service_port)
}

output "cfout" {
  value = [
    {
      name            = var.properties.hostname
      value           = local.service_hostname
    },
    {
      name            = var.properties.port
      value           = local.service_port
    }
  ]
}
