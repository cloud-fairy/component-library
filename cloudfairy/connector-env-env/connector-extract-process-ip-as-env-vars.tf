variable "config" {
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
      name = var.config.privateEndpoint
      value = var.dependency.from_module.public_url
    }
  ]
}