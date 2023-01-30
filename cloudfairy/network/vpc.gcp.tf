variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

locals {
  gcp_project_id = var.dependency.cloud_provider.projectId
  region         = var.dependency.cloud_provider.region
  app_range_name = "app-range"
  svc_range_name = "svc-range"
  app_cidr       = "10.20.0.0/16"
  svc_cidr       = "10.30.0.0/16"
  network_name   = "vpc-${var.project.project_name}-${var.project.environment_name}"
}

resource "google_compute_network" "this" {
  name                    = local.network_name
  project                 = local.gcp_project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "apps" {
  name          = "app-subnetwork"
  ip_cidr_range = "10.1.0.0/16"
  region        = local.region
  network       = google_compute_network.this.id
}

resource "google_compute_subnetwork" "svc" {
  name          = "svc-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = local.region
  network       = google_compute_network.this.id
}



output "cfout" {
  value = {
    network_name  = local.network_name
    subnets_names = ["app-subnetwork", "svc-subnetwork"]
    cidr = {
      apps = google_compute_subnetwork.apps.ip_cidr_range
      svcs = google_compute_subnetwork.svc.ip_cidr_range
    }
  }
}
