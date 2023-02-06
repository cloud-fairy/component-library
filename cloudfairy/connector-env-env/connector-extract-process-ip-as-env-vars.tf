variable "properties" {
  type = object({
    privateEndpoint = string
  })
}

variable "dependency" {
  type = object({
    from_module = object({
      public_url = string
    })
  })
}

output "cfout" {
  value = [
    {
      name = var.properties.privateEndpoint
      value = var.dependency.from_module.endpoint
    }
  ]
}