variable "config" {
  type = any
}

variable "dependency" {
  type = any
}

locals {
  disk_size = "${var.config.disk_size}Gi"
  container_port = var.config.db_image == "mysql:5.6" ? "3306" : "5432"
}

resource "kubernetes_persistent_volume" "volume" {
  metadata {
    name = "sql-volume"
  }
  spec {
    capacity = {
      storage = local.disk_size
    }
    access_modes = ["ReadWriteOnce"]
  }
}

resource "kubernetes_persistent_volume_claim" "claim" {
  metadata {
    name = kubernetes_persistent_volume.volume.name
  }
}

resource "kubernetes_deployment" "db" {
  wait_for_rollout = true
  metadata {
    name = var.config.service_name
    labels = {
      Automation = "cloudfairy"
    }
  }
  spec {
    replicas = 1
    selector = {
      match_labels = {
        App = var.config.service_name
      }
    }
    template {
      metadata {
        label = {
          App = var.config.service_name
        }
      }
      spec {
        container {
          image = var.config.db_image
          image_pull_policy = "IfNotPresent"
          port {
            container_port = local.container_port
          }
        }
      }
    }
  }
}