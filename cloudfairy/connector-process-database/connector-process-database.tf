variable "config" {
  type = object({
    privateEndpoint = string
    dbUser = string
    dbPass = string
    dbName = string
  })
}

variable "dependency" {
  type = any
}

output "cfout" {
  value = {
    kubernetes = {
      secrets = [{
        type = "generic"
        metadata = {
          name = "cloudsql-access"
        }
        data = {
          "cloudsql-access" = file(var.dependency.cloud_provider._c)
        }
      }]
      sidecars = [{
        image = "gcr.io/cloudsql-docker/gce-proxy:1.28.0"
        name = "cloud-sql-proxy"
        command = [
          "/cloud_sql_proxy",
          "-instances=${var.dependency.from_module.connectionName}=tcp:0.0.0.5432"
        ]
        volume_mounts = [
          {
            name = "cloudsql-oauth-credentials"
            mount_path = "/secrets/cloudsql"
            read_only = true
          },
          {
            name = "ssl-certs"
            mount_path = "/etc/ssl/certs"
          }
        ]
      }]
      volumes = [
        {
          name = "cloudsql-oauth-credentials"
          secret = {
            secret_name = "cloudsql_oauth_credentials"
          }
        },
        {
          name = "ssl-certs"
          host_path = {
            path = "/etc/ssl/certs"
          }
        }
      ]
    }
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