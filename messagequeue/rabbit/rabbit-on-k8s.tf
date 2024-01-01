variable "properties" {
  type = any
}
variable "project" {
  type = any
}

variable "dependency" {
  type = any
}

variable "connector" {
  type = any
}

locals {
  has_management     = var.properties.has_management ? 1 : 0
  env_name           = var.project.environment_name
  image              = var.properties.has_management ? "rabbitmq:3-management" : "rabbitmq"
  service_name       = var.properties.local_name
  hostname           = lower(local.service_name)
  inject_env_vars_kv = var.properties.env_vars != "" ? split(",", var.properties.env_vars) : []
  env_vars = flatten([
    for element in local.inject_env_vars_kv : {
      name  = split("=", element)[0]
      value = split("=", element)[1]
    }
  ])
  all_env_vars = flatten([local.env_vars])
}

resource "random_password" "db_root_password" {
  length  = 16
  special = false
}

resource "random_password" "db_root_username" {
  length  = 8
  special = false
}

provider "kubernetes" {
  insecure    = true
  config_path = var.dependency.cloudfairy_cluster.kubeconfig_path # "~/.kube/config"
}

resource "kubernetes_deployment_v1" "rabbit" {
  wait_for_rollout = false
  metadata {
    name      = local.service_name
    namespace = "default"
  }
  spec {
    replicas = try(var.properties.pod_count, 1)
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
        }
        container {
          name              = local.service_name
          image             = local.image
          image_pull_policy = "IfNotPresent"
          env {
            name  = "RABBITMQ_DEFAULT_USER"
            value = random_password.db_root_username.result
          }
          env {
            name  = "RABBITMQ_DEFAULT_PASS"
            value = random_password.db_root_password.result
          }
          dynamic "env" {
            for_each = flatten(local.all_env_vars)
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
          volume_mount {
            name       = "root-volume-claim"
            mount_path = "/etc/rabbitmq"
            sub_path   = ".cloudfairy/volume-data/${local.service_name}"
          }
          dynamic "lifecycle" {
            for_each = range(local.has_management)
            content {
              post_start {
                exec {
                  command = [
                    "/bin/sh",
                    "-c",
                    "sleep 10 && rabbitmq-plugins enable rabbitmq_management"
                  ]
                }
              }
            }
          }
          dynamic "port" {
            for_each = range(local.has_management)
            content {
              container_port = 15672
              protocol       = "TCP"
            }
          }
          dynamic "port" {
            for_each = range(local.has_management)
            content {
              container_port = 8080
              protocol       = "TCP"
            }
          }
          port {
            container_port = 5672
            protocol       = "TCP"
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
  }
  spec {
    type = "ClusterIP"
    selector = {
      "app" = local.service_name
    }
    port {
      port        = 5672
      target_port = 5672
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_service_v1" "mgmt_service" {
  count = local.has_management
  metadata {
    name      = "${local.service_name}-ui"
    namespace = "default"
  }
  spec {
    type = "NodePort"
    selector = {
      "app" = local.service_name
    }
    port {
      name        = "15672"
      port        = 15672
      target_port = 15672
      protocol    = "TCP"
    }
    port {
      name        = "8080"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "mgmt_ingress" {
  count = local.has_management
  metadata {
    name = "${local.service_name}-ui"
    labels = {
      app = local.service_name
    }
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
    }
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "${local.service_name}-ui.localhost"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "${local.service_name}-ui"
              port {
                number = 15672
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "ingress" {
  count = var.properties.has_ingress
  metadata {
    name = local.service_name
    labels = {
      app = local.service_name
    }
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
    }
  }
  spec {
    ingress_class_name = "traefik"
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
                number = 5672
              }
            }
          }
        }
      }
    }
  }
}


output "cfout" {
  sensitive = true
  value = {
    db_user  = base64encode(random_password.db_root_username.result)
    db_pass  = base64encode(random_password.db_root_password.result)
    hostname = local.service_name
    port     = 5672
  }
}
