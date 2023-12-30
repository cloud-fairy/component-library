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
      value = var.dependency.from_module.hostname
    },
    {
      name  = var.properties.port
      value = var.dependency.from_module.port
    },
    {
      name  = var.properties.user
      value = base64decode(var.dependency.from_module.db_user)
    },
    {
      name  = var.properties.pass
      value = base64decode(var.dependency.from_module.db_pass)
    }
  ]
}
