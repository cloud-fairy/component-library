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
  env_name           = var.project.environment_name
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

resource "kubernetes_deployment_v1" "mongo" {
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
          image             = "mongo"
          image_pull_policy = "IfNotPresent"
          env {
            name  = "MONGO_INITDB_ROOT_USERNAME"
            value = random_password.db_root_username.result
          }
          env {
            name  = "MONGO_INITDB_ROOT_PASSWORD"
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
            mount_path = "/data/db"
            sub_path   = ".cloudfairy/volume-data/${local.service_name}"
          }
          port {
            container_port = 27017
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
      port        = 27017
      target_port = 27017
      protocol    = "TCP"
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
                number = 27017
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
    port     = 27017
  }
}

output "cfdocs" {
  value = <<EOF
# ${local.service_name} mongo database
MongoDB database.

User and password auto-generated, injectable via environment variables to connected services.

${var.properties.has_ingress > 0 ? "Access: ${local.service_name}.localhost:8000" : "Internal access only"}
EOF
}
