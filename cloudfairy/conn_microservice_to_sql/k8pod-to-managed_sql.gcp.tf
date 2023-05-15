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
  connection_name    = var.dependency.from_module.database.connection_name
  private_ip_address = var.dependency.from_module.database.private_ip_address
  ip_address         = var.dependency.from_module.database.ip_address
  public_ip_address  = var.dependency.from_module.database.public_ip_address
  username           = var.dependency.from_module.database.username
  password           = var.dependency.from_module.database.password
  ca_cert            = var.dependency.from_module.database.ca_cert
}



output "cfout" {
  value = {
    environment_variables = {
      host = {
        name  = var.properties.hostname_env_var
        value = local.ip_address
      }
      connection = {
        name  = var.properties.connection_env_var
        value = local.connection_name
      }
      user = {
        name  = var.properties.username_env_var
        value = local.username
      }
      password = {
        name  = var.properties.password_env_var
        value = local.password
      }
    }
  }
}
