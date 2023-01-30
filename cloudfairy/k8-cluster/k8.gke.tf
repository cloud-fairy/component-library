variable "properties" {
  type = any
}
variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

data "google_compute_zones" "available" {}
data "google_client_config" "this" {}

locals {
  cluster_name   = "${var.project.project_name}-${var.project.environment_name}-cluster"
  region         = var.dependency.cloud_provider.region
  gcp_project_id = var.dependency.cloud_provider.projectId
  network = {
    name          = var.dependency.network.network_name
    subnetswork   = var.dependency.network.subnets_names[0]
    ip_range_pods = var.dependency.network.cidr.apps
    ip_range_svcs = var.dependency.network.cidr.svcs
  }
}

resource "google_container_cluster" "this" {
  name     = local.cluster_name
  location = local.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "${local.cluster_name}-pool"
  location   = local.region
  cluster    = google_container_cluster.this.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

module "gke_auth" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  version      = "24.1.0"
  depends_on   = [google_container_cluster.this]
  project_id   = local.gcp_project_id
  location     = local.region
  cluster_name = google_container_cluster.this.name
}






output "cfout" {
  sensitive = true
  value = {
    kube_config            = module.gke_auth.kubeconfig_raw
    endpoint               = "https://${google_container_cluster.this.endpoint}"
    token                  = data.google_client_config.this.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.this.master_auth.0.cluster_ca_certificate)
    client_certificate     = base64decode(google_container_cluster.this.master_auth.0.client_certificate)
    client_key             = base64decode(google_container_cluster.this.master_auth.0.client_key)
  }
}
