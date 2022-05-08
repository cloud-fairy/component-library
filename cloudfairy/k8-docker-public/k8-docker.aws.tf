provider "kubernetes" {
  host = var.dependency.k8_cluster.host
  token = var.dependency.k8_cluster.token
  cluster_ca_certificate = base64decode(var.dependency.k8_cluster.client_cert)
}

variable "config" {
  type = any
}

variable "dependency" {
  type = any
}

locals {

}

resource "kubernetes_deployment" "default" {
  wait_for_rollout = false
  metadata {
    name = var.config.service_name
    labels = {
      Automation = "cloudfairy"
    }
  }
  spec {
    replicas = var.config.pod_count
    selector {
      match_labels = {
        App = var.config.service_name
      }
    }
    template {
      metadata {
        labels = {
          App = var.config.service_name
        }
      }
      spec {
        container {
          image = var.config.docker_image
          name = var.config.service_name
          port {
            container_port = var.config.port_to
          }
          image_pull_policy = "Always"
          resources {
            limits = {
              cpu = "0.25"
              memory = "512M"
            }
            requests = {
              cpu = "0.15"
              memory = "128M"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "default" {
  metadata {
    name = "k8service-${var.config.service_name}"
  }
  spec {
    selector = {
      App = kubernetes_deployment.default.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port = var.config.port_from
      target_port = var.config.port_to
    }
  }
}

output cfout {
  value = {
    dns_name = kubernetes_service.default.metadata.name
    port = var.config.port_from
    endpoint = "http://${output.cfout.DNS_NAME}:${output.cfout.PORT}"
  }
}

output "instructions" {
  value = {
    "Accessible internally via http://${output.cfout.DNS_NAME}:${output.cfout.PORT}"
  }
}