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
  cluster          = var.dependency.cloudfairy_cluster
  env_name         = var.project.environment_name
  service_name     = var.properties.local_name
  docker_tag       = data.external.env.result["CI_COMMIT_SHA"] != "" ? data.external.env.result["CI_COMMIT_SHA"] : var.project.environment_name
  conn_to_dockers  = try(var.connector.cloudfairy_service_to_dockerhub, [])
  conn_to_services = try(var.connector.cloudfairy_service_to_service, [])
  conn_to_storages = try(var.connector.cloudfairy_service_to_storage, [])
  conn_to_rds      = try(var.connector.cloudfairy_k8_microservice_to_managed_sql, [])
  inject_env_vars  = flatten([local.conn_to_dockers, local.conn_to_services, local.conn_to_storages, local.conn_to_rds])
}

data "google_client_config" "provider" {}

provider "kubernetes" {
  host  = "https://${local.cluster.hostname}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    local.cluster.cluster_ca_certificate
  )
}

data "external" "env" {
  program = ["bash", "${path.module}/env.bash"]
}

resource "kubernetes_deployment_v1" "app" {
  wait_for_rollout = false
  metadata {
    name      = local.service_name
    namespace = "default"
  }
  spec {
    replicas = var.properties.pod_count
    selector {
      match_labels = {
        "app" = local.service_name
      }
    }
    template {
      metadata {
        labels = {
          "app" = local.service_name
          "env" = local.env_name
        }
      }
      spec {
        service_account_name = "default"
        container {
          name = local.service_name
          # europe-north1-docker.pkg.dev/cloud-fairy-324304/stg-todoapp-repo/bff:stg
          image             = "${var.dependency.cloudfairy_cluster.container_registry_url}/${local.service_name}:${local.docker_tag}"
          image_pull_policy = "Always"
          dynamic "env" {
            for_each = flatten(local.conn_to_dockers)
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
          port {
            container_port = var.properties.container_port
            protocol       = "TCP"
          }
          resources {
            limits = {
              "memory" = "1Gi"
              "cpu"    = "100m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = local.service_name
    namespace = "default"
    labels = {
      "app" = local.service_name
    }
    annotations = {
      "cloud.google.com/neg" = "{\"ingress\": true,\"exposed_ports\":{\"${var.properties.container_port}\":{}}}"
    }
  }
  spec {
    type = (var.properties.has_ingress == 1 || var.properties.has_ingress == "1") ? "LoadBalancer" : "NodePort"
    port {
      port        = (var.properties.has_ingress == 1 || var.properties.has_ingress == "1") ? 80 : var.properties.container_port
      target_port = var.properties.container_port
    }
    selector = {
      "app" = local.service_name
    }

    dynamic "port" {
      for_each = var.properties.debug_port == "-1" ? [] : [var.properties.debug_port]
      content {
        name        = "debug-port"
        port        = var.properties.debug_port
        target_port = var.properties.debug_port
      }
    }
  }
}



resource "kubernetes_ingress_v1" "app" {
  count = var.properties.has_ingress
  metadata {
    name = local.service_name
    labels = {
      "app" = local.service_name
    }
    namespace = "default"
    annotations = {
      # "nginx.ingress.kubernetes.io/use-regex"      = "true"
      "kubernetes.io/ingress.class" : "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$1"
    }
  }
  spec {
    # ingress_class_name = "nginx"
    rule {
      http {
        path {
          path      = "/${local.service_name}/*"
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
    pod_count    = var.properties.pod_count
    service_name = local.service_name
    hostname     = local.service_name
    port         = var.properties.container_port
  }
}
