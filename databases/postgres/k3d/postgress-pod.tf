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
  config_path = var.dependency.cloudfairy_cluster.kubeconfig_path # "~/.kube/config"
}

locals {
  env_name        = var.project.environment_name
  service_name    = var.properties.local_name
  hostname        = lower(local.service_name)
  admin_usernanme = var.properties.pod_admin_username
  databases       = try(split(",", var.properties.pod_databases), [])
}

resource "random_password" "pg_root_password" {
  length  = 16
  special = false
}

resource "kubernetes_deployment" "deployment" {
  wait_for_rollout = true
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
        service_account_name = var.dependency.cloudfairy_cluster.service_account
        volume {
          name = "root-volume-claim"
          persistent_volume_claim {
            claim_name = "root-volume-claim"
          }
        }
        container {
          name              = local.service_name
          image             = "postgres"
          image_pull_policy = "IfNotPresent"
          env {
            name  = "POSTGRES_USER"
            value = local.admin_usernanme
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = random_password.pg_root_password.result
          }
          volume_mount {
            name       = "root-volume-claim"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "${local.service_name}/data"
          }
          port {
            container_port = 5432
            protocol       = "TCP"
          }
          resources {
            limits = {
              memory = "1Gi"
              cpu    = "500m"
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
      port        = 80
      target_port = 5432
      protocol    = "TCP"
    }
    selector = {
      "app" = local.service_name
    }
  }
}

resource "kubernetes_ingress_v1" "ingress" {
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
                number = 5432
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
    hostname     = local.service_name
    service_name = local.service_name
    port         = 5432
    pg_user      = local.admin_usernanme
    pg_pass      = random_password.pg_root_password.result
  }
}
