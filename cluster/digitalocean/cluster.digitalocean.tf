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
  prefix       = var.dependency.cloud_provider.projectId
  cluster_name = lower("${local.prefix}-${var.project.environment_name}-${var.project.project_name}")
  pool_name    = lower("${local.prefix}-${var.project.environment_name}-${var.project.project_name}-np")
  region       = var.project.CLOUD_REGION
}

resource "digitalocean_container_registry" "repo" {
  name                   = "${local.cluster_name}-repo"
  subscription_tier_slug = "starter"
}

resource "digitalocean_kubernetes_cluster" "this" {
  depends_on = [digitalocean_container_registry.repo, digitalocean_container_registry_docker_credentials.creds]
  name       = local.cluster_name
  region     = local.region
  # Grab the latest version slug from `doctl kubernetes options versions`
  version = "1.28.2-do.0"

  node_pool {
    name       = local.pool_name
    size       = "s-2vcpu-4gb"
    auto_scale = true
    min_nodes  = 3
    max_nodes  = 7
  }

  registry_integration = true
}

resource "digitalocean_container_registry_docker_credentials" "creds" {
  registry_name = digitalocean_container_registry.repo.name
}

provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.this.endpoint
  token                  = digitalocean_kubernetes_cluster.this.kube_config.0.token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
}

output "cfout" {
  sensitive = true
  value = {
    cluser_id              = digitalocean_kubernetes_cluster.this.id # google_container_cluster.this.id
    hostname               = digitalocean_kubernetes_cluster.this.endpoint
    client_certificate     = digitalocean_kubernetes_cluster.this.kube_config.0.client_certificate
    client_key             = digitalocean_kubernetes_cluster.this.kube_config.0.client_key
    cluster_ca_certificate = digitalocean_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate
    kube_config            = digitalocean_kubernetes_cluster.this.kube_config
    container_registry_url = "${digitalocean_container_registry.repo.endpoint}"
  }
}
