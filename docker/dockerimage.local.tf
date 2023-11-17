variable "properties" {
  # service_name
  # repo_url
  type = any
}

variable "project" {
  # environment_name
  type = any
}

variable "dependency" {
  # cloud_provider
  # cluster
  type = any
}

variable "connector" {
  # cloudfairy_k8_microservice_to_managed_sql : any[]
  type = any
}

provider "kubernetes" {
  insecure    = true
  config_path = var.dependency.eavichay_cluster.kubeconfig_path # "~/.kube/config"
}

locals {
  env_name           = var.project.environment_name
  service_name       = var.properties.local_name
  hostname           = lower(local.service_name)
  conn_to_services   = try(var.connector.cloudfairy_application_to_docker, [])
  inject_env_vars_kv = var.properties.env_vars != "" ? try(toset(var.properties.env_vars), toset([var.properties.env_vars])) : []
  env_vars = flatten([
    for element in local.inject_env_vars_kv : {
      name  = split("=", element)[0]
      value = split("=", element)[1]
    }
  ])
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
        service_account_name = var.dependency.eavichay_cluster.service_account
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
              cpu    = "500m"
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
  count = var.properties.isexposed ? 1 : 0
  metadata {
    name = local.service_name
    labels = {
      app = local.service_name
    }
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                      = "traefik"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web,websecure"
    }
  }
  spec {
    rule {
      host = "${local.service_name}.localhost"
      http {
        path {
          path      = "/"
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
    hostname = local.service_name
    port     = var.properties.container_port
    env_vars = local.env_vars
  }
}
