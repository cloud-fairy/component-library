variable "properties" {
  # deployment_name
  # port
  # with_ingress "true" | "false"
  type = any
}

variable "project" {
  # environment_name
  type = any
}

variable "dependency" {
  # cloud_provider
  # k8_cluster
}

variable "connector" {
  # cloudfairy_k8_microservice_to_managed_sql : any[]
  type = any
}

locals {
  dependency      = try(jsondecode(var.dependency), var.dependency)
  connector       = try(jsondecode(var.connector), var.connector)
  deployment_name = var.properties.deployment_name
  env             = var.project.environment_name
  cluster_host    = local.dependency.k8_cluster.endpoint
  kubeconfig      = local.dependency.k8_cluster.kube_config
  k8_cert         = local.dependency.k8_cluster.cluster_ca_certificate

  cpu = {
    required = var.properties.cpu[0]
    limit    = var.properties.cpu[1]
  }
  memory = {
    required = var.properties.memory[0]
    limit    = var.properties.memory[1]
  }
}

resource "google_container_registry" "registry" {
  project = local.dependency.cloud_provider.projectId
}

provider "kubernetes" {
  host                   = local.cluster_host
  cluster_ca_certificate = local.k8_cert
  token                  = local.dependency.k8_cluster.token
  client_key             = local.dependency.k8_cluster.client_key
  client_certificate     = local.dependency.k8_cluster.client_certificate
  # client_key             = local.dependency.k8_cluster.cluster_key
}

resource "kubernetes_deployment" "example" {
  wait_for_rollout = false
  metadata {
    name = local.deployment_name
    labels = {
      test       = local.deployment_name
      cloudfairy = "true"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.deployment_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.deployment_name
        }
      }

      spec {
        dynamic "container" {
          for_each = local.connector.cloudfairy_k8_microservice_to_managed_sql
          content {
            name = "sql-proxy-${container.key}"
            # image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest"
            image = "gcr.io/cloudsql-docker/gce-proxy:1.28.0"
            # command = ["/cloud_sql_proxy"]
            args = [
              # "--private-ip",
              "${container.value.environment_variables.connection.value}"
            ]
            security_context {
              run_as_non_root = true
            }
            resources {
              requests = {
                cpu    = "250m"
                memory = "1Gi"
              }
              limits = {
                cpu    = "500m"
                memory = "2Gi"
              }
            }
          }
        }

        container {
          image = "gcr.io/${local.dependency.cloud_provider.projectId}/${local.deployment_name}:latest"
          name  = local.deployment_name

          resources {
            limits = {
              cpu    = local.cpu.limit
              memory = local.memory.limit
            }
            requests = {
              cpu    = local.cpu.required
              memory = local.memory.required
            }
          }

          # liveness_probe {
          #   http_get {
          #     path = "/nginx_status"
          #     port = 80

          #     http_header {
          #       name  = "X-Custom-Header"
          #       value = "Awesome"
          #     }
          #   }

          #   initial_delay_seconds = 3
          #   period_seconds        = 3
          # }
        }
      }
    }
  }
}

resource "kubernetes_service" "this" {
  metadata {
    name = "service-${local.deployment_name}"
  }
  spec {
    selector = {
      app = local.deployment_name
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = var.properties.port
    }

    type = "LoadBalancer"
  }
}

output "cfout" {
  value = {}
}
