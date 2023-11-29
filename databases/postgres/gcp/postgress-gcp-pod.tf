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
  cluster         = var.dependency.cloudfairy_cluster
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

data "google_client_config" "provider" {}

provider "kubernetes" {
  host  = "https://${local.cluster.hostname}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    local.cluster.cluster_ca_certificate
  )
}

resource "kubernetes_storage_class_v1" "storage_class" {
  metadata {
    name = "fast-storageclass"
    labels = {
      "app" = service.local_name
    }
  }
  storage_provisioner    = "pd.csi.storage.gke.io"
  volume_binding_mode    = "WairForFirstConsumer"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  parameters = {
    "type" = "pd-balanced"
  }
}

resource "kubernetes_stateful_set_v1" "psql" {
  depends_on       = [kubernetes_storage_class_v1.storage_class]
  wait_for_rollout = false
  metadata {
    name = local.service_name
    labels = {
      "app"     = local.service_name
      namespace = "default"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app" = local.service_name
      }
    }
    service_name = local.service_name
    template {
      metadata {
        labels = {
          "app" = local.service_name
        }
      }
      spec {
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "DoNotSchedule"
          label_selector {
            match_labels = {
              "app" = local.service_name
            }
          }
        }
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app"
                  operator = "In"
                  values   = [local.local.service_name]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
        container {
          name  = local.service_name
          image = "postgres"
          env {
            name  = "POSTGRES_USER"
            value = local.admin_usernanme
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = random_password.pg_root_password.result
          }
          port {
            name           = "postgres"
            container_port = 5432
          }
          resources {
            limits = {
              "memory"           = "1Gi"
              "cpu"              = "500m"
              "empheral-storage" = "1Gi"
            }
            requests = {
              "cpu"              = "500m"
              "empheral-storage" = "1Gi"
              "memory"           = "1Gi"
            }
          }
          volume_mount {
            name       = "${local.service_name}-volumemount"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }
    update_strategy {
      rolling_update {
        partition = 0
      }
      type = "RollingUpdate"
    }
    volume_claim_template {
      metadata {
        name = "${local.service_name}-volumeclaim"
        labels = {
          "app" = local.service_name
        }
      }
      spec {
        storage_class_name = "fast-storageclass"
        access_modes       = ["ReadWriteOnce"]
        resources {
          requests = {
            "storage" = "10Gi"
          }
        }
      }
    }
  }
}


output "cfout" {
  value = {
    pod_count    = 1
    service_name = local.service_name
    hostname     = local.service_name
    port         = 5432
  }
}
