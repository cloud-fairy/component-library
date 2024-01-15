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
  cluster            = var.dependency.cloudfairy_cluster
  env_name           = var.project.environment_name
  service_name       = var.properties.local_name
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

data "google_client_config" "provider" {}

provider "kubernetes" {
  host  = "https://${local.cluster.hostname}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    local.cluster.cluster_ca_certificate
  )
}

resource "kubernetes_storage_class_v1" "storage" {
  metadata {
    name = "${local.service_name}-storage-class"
  }
  storage_provisioner    = "kubernetes.io/gce-pd"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
  parameters = {
    type = "pd-ssd"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "storage" {
  metadata {
    name = "${local.service_name}-pvc"
  }
  spec {
    storage_class_name = "${local.service_name}-storage-class"
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
}

resource "kubernetes_stateful_set_v1" "mongo" {
  wait_for_rollout = false
  metadata {
    name      = local.service_name
    namespace = "default"
  }
  spec {
    service_name = local.service_name
    replicas     = 1
    selector {
      match_labels = {
        "app" = local.service_name
      }
    }
    volume_claim_template {
      metadata {
        name = "${local.service_name}-data"
      }
      spec {
        storage_class_name = "${local.service_name}-storage-class"
        access_modes       = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "20Gi"
          }
        }
      }
    }
    template {
      metadata {
        labels = {
          "app" = local.service_name
        }
      }
      spec {
        container {
          name              = local.service_name
          image             = "mongo"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 27017
          }
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
            name       = "${local.service_name}-data"
            mount_path = "/data/db"
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
    selector = {
      app = local.service_name
    }
    port {
      port        = 27017
      target_port = 27017
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
