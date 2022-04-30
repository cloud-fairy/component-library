data "google_client_config" "default" {}

provider "kubernetes" {
  host = var.dependency.k8_cluster.container.host
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(var.dependency.k8_cluster.container.ca_cert)
}

variable "config" {
  type = any
}

variable "dependency" {
  type = any
  # type = object({
  #   k8_cluster = object({
  #     container = object({
  #       id          = string
  #       self_link   = string
  #       endpoint    = string
  #       client_cert = string
  #       client_key  = string
  #       ca_cert     = string
  #       host        = string
  #     })
  #   })
  #   cloud_provider = any
  #   cloudfairy_connector_extract_database_env_vars = optinal(any)
  # })
}

locals {
  db_envs = try(var.dependency.cloudfairy_connector_extract_database_env_vars.env, [])
  projectId = var.dependency.cloud_provider.projectId
  volumes = try(var.dependency.cloudfairy_connector_extract_database_env_vars.kubernetes.volumes, [])
  sidecars = try(var.dependency.cloudfairy_connector_extract_database_env_vars.kubernetes.sidecars, [])
  sql_secrets = try(var.dependency.cloudfairy_connector_extract_database_env_vars.kubernetes.secrets, [])
}

data "kubernetes_secret" "sa_token" {
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_secret" "example" {
  metadata {
    name = "docker-registry"
  }

  data = {
    "docker-server" = "https://gcr.io"
    "docker-username" = "_json_key"
    "docker-password" = file(var.dependency.cloud_provider._c)
  }

  type = "gcr-json-key"
}

resource kubernetes_secret "sql_connector_secrets" {
  for_each = { for secret in local.sql_secrets : secret.metadata.name => secret }
  metadata {
    name = each.key
  }
  data = each.value.data
  type = each.value.type
}

resource "kubernetes_service" "default" {
  metadata {
    name = "k8service-${var.config.service_name}"
  }
  spec {
    selector = {
      App = kubernetes_deployment.default.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = var.config.container_port
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_ingress" "default" {
  wait_for_load_balancer = true
  metadata {
    name = "k8ingress-${var.config.service_name}"
  }
  spec {
    rule {
      http {
        path {
          path = "/*"
          backend {
            service_name = kubernetes_service.default.metadata.0.name
            service_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "default" {
  metadata {
    name = var.config.service_name
    labels = {
      Automation = "cloudfairy"
    }
  }
  spec {
    replicas = var.config.pod_count
    selector {
      match_labels = {
        App = var.config.service_name
      }
    }
    template {
      metadata {
        labels = {
          App = var.config.service_name
        }
      }
      spec {
        dynamic "container" {
          for_each = local.sidecars
          content {
            image = container.value.image
            name = container.value.name
            command = container.value.command
            dynamic "volume_mount" {
              for_each = try(container.value.volume_mounts, [])
              content {
                name = volume_mount.value.name
                mount_path = volume_mount.value.mount_path
                read_only = try(volume_mount.value.read_only, false)
              }
            }
          }
        }
        volume {
          name = "kube-certificate"
          mount_path = "/etc/ssl/certs/kube-ca.crt"
          sub_path = "ca.crt"
        }
        dynamic "volume" {
          for_each = local.volumes
          content {
            name = volume.value.name
            dynamic secret {
              for_each = {for key, value in volume.value : key => value if can(value.secret)}
              content {
                secret_name = volume.value.secret.secret_name
              }
            }
            dynamic host_path {
              for_each = {for key, value in volume.value : key => value if can(value.host_path)}
              content {
                path = volume.value.host_path.path
              }
            }
          }
        }
        container {
          image = "gcr.io/${var.dependency.cloud_provider.projectId}/${var.config.service_name}:latest"
          name = var.config.service_name
          port {
            container_port = var.config.container_port
          }
          dynamic "env" {
            for_each = local.db_envs
            content {
              name = env.value["name"]
              value = env.value["value"]
            }
          }
          image_pull_policy = "Always"
          resources {
            limits = {
              cpu = "0.25"
              memory = "512M"
            }
            requests = {
              cpu = "0.15"
              memory = "128M"
            }
          }
        }
      }
    }
  }
}