variable "config" {
  type = object({
    privateEndpoint = string
    dbUser = string
    dbPass = string
    dbName = string
  })
}

variable "dependency" {
  type = object({
    from_module = any
  })
}

output "cfout" {
  value = {
    sql_proxy_container = [{
      image = "gcr.io/cloudsql-docker/gce-proxy:1.19.1"
      name = "cloud-sql-proxy"
      command = [
        "/cloud_sql_proxy",
        "-instances=${var.dependency.from_module.connectionName}=tcp:0.0.0.5432"
      ]
    }]
    init_container = [{
      image = "gcr.io/google.com/cloudsdktool/cloud-sdk:326.0.0-alpine"
      name = "workload-identity-initcontainer"
      command = [
        "/bin/bash",
        "-c",
        "curl -s -H 'Metadata-Flavor: Google' 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' --retry 30 --retry-connrefused --retry-max-time 30 || exit 1"
      ]
    }]
    env = [
      {
        name = var.config.privateEndpoint
        value = var.dependency.from_module.databaseIPAddress
      },
      {
        name = var.config.dbUser
        value = var.dependency.from_module.admin_username
      },
      {
        name = var.config.dbPass
        value = var.dependency.from_module.admin_password
      },
      {
        name = var.config.dbName
        value = var.dependency.from_module.databaseName
      }
    ]
  }
}

# env {
#   name = "SOURCE"
#   value = "remote"
# }