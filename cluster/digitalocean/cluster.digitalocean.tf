variable "properties" {
  type = any
}

variable "project" {
  type = any
}

variable "dependency" {
  type    = any
  default = {}
}

locals {
  cluster_name = lower("${var.project.environment_name}-${var.project.project_name}")
  pool_name    = lower("${var.project.environment_name}-${var.project.project_name}-np")
  region       = var.project.CLOUD_REGION
}

resource "digitalocean_kubernetes_cluster" "this" {
  name   = local.cluster_name
  region = local.region
  # Grab the latest version slug from `doctl kubernetes options versions`
  version = "1.28.2-do.0"

  node_pool {
    name       = local.pool_name
    size       = "s-2vcpu-2gb"
    node_count = 2

    taint {
      key    = "workloadKind"
      value  = "database"
      effect = "NoSchedule"
    }
  }
}

output "cfout" {
  sensitive = true
  value = {
    cluser_id              = digitalocean_kubernetes_cluster.this.id # google_container_cluster.this.id
    hostname               = digitalocean_kubernetes_cluster.this.endpoint
    client_certificate     = digitalocean_kubernetes_cluster.this.kube_config.0.client_certificate
    client_key             = digitalocean_kubernetes_cluster.this.kube_config.0.client_key
    cluster_ca_certificate = digitalocean_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate
    # service_account        = local.service_account
    # container_registry_url = "${local.region}-docker.pkg.dev/${var.project.PROJECT_ID}/${local.cluster_name}-repo"
  }
}
