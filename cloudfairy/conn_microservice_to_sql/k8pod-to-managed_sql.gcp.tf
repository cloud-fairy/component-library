variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}


locals {
  # var.dependency.from_module <---- sql database
  port               = var.dependency.from_module.port
  hostname           = var.dependency.from_module.endpoint
  username           = var.dependency.from_module.uid
  password           = var.dependency.from_module.psw
}



output "cfout" {
  value = [{
    name  = var.properties.username_env_var
    value = local.username
  },
  {
    name  = var.properties.password_env_var
    value = local.password
  },
  {
    name  = var.properties.hostname_env_var
    value = local.hostname
  },
  {
    name  = var.properties.port_env_var
    value = tostring(local.port)
  }
  ]
}
