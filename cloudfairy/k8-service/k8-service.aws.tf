provider "kubernetes" {
  host                   = var.dependency.k8_cluster.host
  token                  = var.dependency.k8_cluster.token
  cluster_ca_certificate = base64decode(var.dependency.k8_cluster.client_cert)
}

variable "config" {
  type = any
}

variable "dependency" {
  type = any
}

locals {
  db_envs     = try(var.dependency.cloudfairy_connector_extract_database_env_vars.env, [])
  projectId   = var.dependency.cloud_provider.projectId
  volumes     = try(var.dependency.cloudfairy_connector_extract_database_env_vars.kubernetes.volumes, [])
  sidecars    = try(var.dependency.cloudfairy_connector_extract_database_env_vars.kubernetes.sidecars, [])
  sql_secrets = try(var.dependency.cloudfairy_connector_extract_database_env_vars.kubernetes.secrets, [])
}

resource "kubernetes_secret" "sql_connector_secrets" {
  for_each = { for secret in local.sql_secrets : secret.metadata.name => secret }
  metadata {
    name = each.key
  }
  data = each.value.data
  type = each.value.type
}

resource "aws_ecr_repository" "default" {
  name                 = var.config.service_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

// https://aws_account_id.dkr.ecr.region.amazonaws.com/v2/

resource "kubernetes_service" "default" {
  metadata {
    name = "k8service-${var.config.service_name}"
  }
  spec {
    selector = {
      App = kubernetes_deployment.default.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = var.config.container_port
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_ingress" "default" {
  wait_for_load_balancer = true
  metadata {
    name = "k8ingress-${var.config.service_name}"
  }
  spec {
    rule {
      http {
        path {
          path = "/*"
          backend {
            service_name = kubernetes_service.default.metadata.0.name
            service_port = 80
          }
        }
      }
    }
  }
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
        dynamic "container" {
          for_each = local.sidecars
          content {
            image   = container.value.image
            name    = container.value.name
            command = container.value.command
            dynamic "volume_mount" {
              for_each = try(container.value.volume_mounts, [])
              content {
                name       = volume_mount.value.name
                mount_path = volume_mount.value.mount_path
                read_only  = try(volume_mount.value.read_only, false)
              }
            }
          }
        }
        dynamic "volume" {
          for_each = local.volumes
          content {
            name = volume.value.name
            dynamic "secret" {
              for_each = { for key, value in volume.value : key => value if can(value.secret) }
              content {
                secret_name = volume.value.secret.secret_name
              }
            }
            dynamic "host_path" {
              for_each = { for key, value in volume.value : key => value if can(value.host_path) }
              content {
                path = volume.value.host_path.path
              }
            }
          }
        }
        container {
          image = "${aws_ecr_repository.default.repository_url}:latest"
          name  = var.config.service_name
          port {
            container_port = var.config.container_port
          }
          dynamic "env" {
            for_each = local.db_envs
            content {
              name  = env.value["name"]
              value = env.value["value"]
            }
          }
          image_pull_policy = "Always"
          resources {
            limits = {
              cpu    = "0.25"
              memory = "512M"
            }
            requests = {
              cpu    = "0.15"
              memory = "128M"
            }
          }
        }
      }
    }
  }
}

output "instructions" {
  value = {
    "deployment_h" = <<EOF
Updating your service is by simply pushing a new container to your dedicated repository.
Use the following command: docker push ${aws_ecr_repository.default.repository_url}:latest
If your docker is not logged in to your AWS container registry, type aws ecr get-login.

Read more here: https://aws.amazon.com/blogs/compute/authenticating-amazon-ecr-repositories-for-docker-cli-with-credential-helper/
EOF
    "deployment"   = "docker push ${aws_ecr_repository.default.repository_url}:latest"
  }
}
