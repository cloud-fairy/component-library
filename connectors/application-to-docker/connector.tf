variable "properties" {
  type = any
}

variable "dependency" {
  type = object({
    from_module = any
  })
  default = {
    from_module = {
      hostname = ""
      port     = ""
    }
  }
}

output "cfout" {
  value = [
    {
      name  = var.properties.hostname
      value = var.dependency.from_module.service_name
    },
    {
      name  = var.properties.port
      value = var.dependency.from_module.port
    }
  ]
}
