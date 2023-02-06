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
  app_cidr       = "10.0.0.0/24"
  svc_cidr       = "10.0.1.0/24"
  db_cidr        = "10.0.2.0/24"
  network_name   = "vpc-${var.project.project_name}-${var.project.environment_name}"
}

resource "google_compute_network" "this" {
  name                    = local.network_name
  project                 = local.gcp_project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "apps" {
  name          = "app-subnetwork"
  ip_cidr_range = local.app_cidr
  region        = local.region
  network       = google_compute_network.this.id
}

resource "google_compute_subnetwork" "svc" {
  name          = "svc-subnetwork"
  ip_cidr_range = local.svc_cidr
  region        = local.region
  network       = google_compute_network.this.id
}

resource "google_compute_subnetwork" "db" {
  name          = "db-subnetwork"
  ip_cidr_range = local.db_cidr
  region        = local.region
  network       = google_compute_network.this.id
}



output "cfout" {
  value = {
    network_name  = local.network_name
    subnets_names = ["app-subnetwork", "svc-subnetwork", "db-subnetwork"]
    cidr = {
      apps = google_compute_subnetwork.apps.ip_cidr_range
      svcs = google_compute_subnetwork.svc.ip_cidr_range
      db   = google_compute_subnetwork.db.ip_cidr_range
    }
  }
}
