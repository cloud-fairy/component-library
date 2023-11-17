variable "properties" {
  type = any
}

variable "dependency" {
  type = object({
    from_module = any
  })
}

output "cfout" {
  value = [
    {
      name  = var.properties.hostname
      value = var.dependency.from_module.hostname
    },
    {
      name  = var.properties.port
      value = var.dependency.from_module.port
    }
  ]
}
