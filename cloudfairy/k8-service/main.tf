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
  initContainer = try(var.dependency.cloudfairy_connector_extract_database_env_vars.init_container, [])
  projectId = var.dependency.cloud_provider.projectId
  sqlSidecar = try(var.dependency.cloudfairy_connector_extract_database_env_vars.sql_proxy_container, [])
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
        dynamic "init_container" {
          for_each = local.initContainer
          content {
            image = init_container.value["image"]
            name = init_container.value["name"]
            command = init_container.value["command"]
          }
        }
        dynamic "container" {
          for_each = local.sqlSidecar
          content {
            image = container.value["image"]
            name = container.value["name"]
            command = container.value["command"]
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