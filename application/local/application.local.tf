variable "properties" {
  type = any
}

variable "connector" {
  type    = any
  default = []
}

variable "dependency" {
  type = object({
    cloudfairy_role    = any
    cloudfairy_cluster = any
  })
}

variable "project" {
  type = any
}

provider "external" {}

provider "kubernetes" {
  insecure    = true
  config_path = var.dependency.cloudfairy_cluster.kubeconfig_path # "~/.kube/config"
}


locals {
  env_name         = var.project.environment_name
  service_name     = var.properties.local_name
  docker_tag       = data.external.env.result["CI_COMMIT_SHA"] != "" ? data.external.env.result["CI_COMMIT_SHA"] : var.project.environment_name
  conn_to_dockers  = try(var.connector.cloudfairy_service_to_dockerhub, [])
  conn_to_services = try(var.connector.cloudfairy_service_to_service, [])
  conn_to_pg_pods  = try(var.connector.cloudfairy_service_to_pod_in_cluster, [])
  conn_to_storages = try(var.connector.cloudfairy_service_to_storage, [])
  conn_to_rds      = try(var.connector.cloudfairy_k8_microservice_to_managed_sql, [])
  raw_env_vars     = var.properties.env_vars != "" ? split(",", var.properties.env_vars) : []
  inject_env_vars_kv = flatten([
    for element in local.raw_env_vars : {
      name  = split("=", element)[0]
      value = split("=", element)[1]
    }
  ])
  inject_env_vars = flatten([local.conn_to_pg_pods, local.conn_to_dockers, local.conn_to_services, local.conn_to_storages, local.conn_to_rds, local.inject_env_vars_kv])
}

output "debug" {
  value = local.inject_env_vars_kv
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
        service_account_name = var.dependency.cloudfairy_cluster.service_account
        volume {
          name = "root-volume-claim"
          persistent_volume_claim {
            claim_name = "root-volume-claim"
          }
          # host_path {
          #   path = "/mnt/cloudfairy/root"
          # }
        }
        container {
          name              = local.service_name
          image             = "k3d-${var.project.project_name}-registry:5000/${local.service_name}:${local.docker_tag}"
          image_pull_policy = "Always"
          volume_mount {
            name       = "root-volume-claim"
            mount_path = var.dependency.cloudfairy_cluster.volume_path
          }
          dynamic "env" {
            for_each = flatten(local.inject_env_vars)
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
              "cpu"    = "500m"
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
  }
  spec {
    type = "NodePort"
    port {
      port        = var.properties.container_port
      target_port = var.properties.container_port
      protocol    = "TCP"
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
        protocol    = "TCP"
      }
    }
  }
}


resource "kubernetes_ingress_v1" "app" {
  metadata {
    name = local.service_name
    labels = {
      "app" = local.service_name
    }
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                      = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web,websecure"
    }
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "${local.service_name}.localhost"
      http {
        path {
          path = "/"
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
