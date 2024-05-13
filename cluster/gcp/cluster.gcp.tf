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


locals {
  network         = var.dependency.cloudfairy_networking.network
  subnet          = var.dependency.cloudfairy_networking.subnet
  service_account = var.dependency.cloudfairy_role.service_account
  cluster_name    = lower("${var.project.environment_name}-${var.project.project_name}")
  region          = var.project.CLOUD_REGION
}


resource "google_container_cluster" "this" {
  deletion_protection      = false
  network                  = local.network.id
  subnetwork               = local.subnet.name
  name                     = local.cluster_name
  location                 = data.google_compute_zones.available.names[0]
  remove_default_node_pool = true
  initial_node_count       = 1
}

data "google_client_config" "provider" {}

data "google_compute_zones" "available" {
  region = local.region
}

resource "google_container_node_pool" "this" {
  name       = "${local.cluster_name}-pool"
  location   = data.google_compute_zones.available.names[0]
  cluster    = google_container_cluster.this.name
  node_count = var.properties.node_count
  autoscaling {
    min_node_count = var.properties.node_count
    max_node_count = var.properties.node_count + 4
  }

  node_config {
    preemptible  = true
    machine_type = "e2-highmem-4"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = local.service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      "env" = var.project.environment_name
    }
  }

  lifecycle {
    ignore_changes = [name_prefix, node_count]
  }
}

resource "google_artifact_registry_repository" "registry" {
  location      = local.region
  repository_id = "${local.cluster_name}-repo"
  format        = "DOCKER"
}

# resource "google_storage_bucket_iam_member" "viewer" {
#   bucket = google_container_registry.registry.id
#   role   = "roles/storage.objectViewer"
#   member = local.service_account.email
# }



output "cfout" {
  sensitive = true
  value = {
    cluser_id              = google_container_cluster.this.id
    hostname               = google_container_cluster.this.endpoint
    port                   = "local.port"
    client_certificate     = google_container_cluster.this.master_auth.0.client_certificate
    client_key             = google_container_cluster.this.master_auth.0.client_key
    cluster_ca_certificate = google_container_cluster.this.master_auth.0.cluster_ca_certificate
    service_account        = local.service_account
    container_registry_url = "${local.region}-docker.pkg.dev/${var.project.PROJECT_ID}/${local.cluster_name}-repo"
  }
}
