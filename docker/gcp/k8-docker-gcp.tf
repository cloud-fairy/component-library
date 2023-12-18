/**

This is a no-op terraform for local cloudfairy environment.

*/

variable "properties" {
  type = any
}

variable "dependency" {
  type    = any
  default = {}
}

variable "project" {
  type = any
}

variable "connector" {
  type    = any
  default = []
}


locals {
  cluster            = var.dependency.cloudfairy_cluster
  env_name           = var.project.environment_name
  service_name       = var.properties.local_name
  conn_to_services   = try(var.connector.cloudfairy_application_to_docker, [])
  inject_env_vars_kv = var.properties.env_vars != "" ? split(",", var.properties.env_vars) : []
  env_vars = flatten([
    for element in local.inject_env_vars_kv : {
      name  = split("=", element)[0]
      value = split("=", element)[1]
    }
  ])
  ingress_count = var.properties.isexposed ? 1 : 0
}

data "google_client_config" "provider" {}

provider "kubernetes" {
  host  = "https://${local.cluster.hostname}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    local.cluster.cluster_ca_certificate
  )
}


resource "kubernetes_deployment" "deployment" {
  wait_for_rollout = false
  metadata {
    name      = local.service_name
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app" = local.service_name
      }
    }
    template {
      metadata {
        labels = {
          app = local.service_name
        }
      }
      spec {
        service_account_name = "default"
        container {
          name              = local.service_name
          image             = var.properties.dockerhub_image
          image_pull_policy = "Always"
          port {
            container_port = var.properties.container_port
            protocol       = "TCP"
          }
          resources {
            limits = {
              memory = "1Gi"
              cpu    = "250m"
            }
          }
          dynamic "env" {
            for_each = local.env_vars
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "service" {
  metadata {
    name      = local.service_name
    namespace = "default"
    labels = {
      "app" = local.service_name
    }
  }
  spec {
    type = "ClusterIP"
    port {
      port        = var.properties.container_port
      target_port = var.properties.container_port
      protocol    = "TCP"
    }
    selector = {
      "app" = local.service_name
    }
  }
}

resource "kubernetes_ingress_v1" "ingress" {
  count = local.ingress_count
  metadata {
    name = local.service_name
    labels = {
      app = local.service_name
    }
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      http {
        path {
          path      = "/${local.service_name}/"
          path_type = "Prefix"
          backend {
            service {
              name = local.service_name
              port {
                number = var.properties.container_port
              }
            }
          }
        }
      }
    }
  }
}


output "cfout" {
  value = {
    hostname     = local.cluster.hostname
    port         = var.properties.container_port
    env_vars     = local.env_vars
    service_name = local.service_name
  }
}
