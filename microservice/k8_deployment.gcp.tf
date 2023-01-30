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

locals {
  dependency      = try(jsondecode(var.dependency), var.dependency)
  deployment_name = var.properties.deployment_name
  env             = var.project.environment_name
  cluster_host    = local.dependency.k8_cluster.endpoint
  kubeconfig      = local.dependency.k8_cluster.kube_config
  k8_cert         = local.dependency.k8_cluster.cluster_ca_certificate
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
        container {
          image = "gcr.io/${local.dependency.cloud_provider.projectId}/${local.deployment_name}:latest"
          name  = local.deployment_name

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
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
