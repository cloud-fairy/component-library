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
  project_id    = var.project.PROJECT_ID
  env_name      = lower(var.project.environment_name)
  project_name  = lower(var.project.project_name)
  network_name  = "${local.env_name}-${local.project_name}-network"
  subnet_prefix = lower(local.network_name)
  region        = var.project.CLOUD_REGION
}

provider "google-beta" {}

resource "google_compute_network" "this" {
  project                 = local.project_id
  auto_create_subnetworks = false
  name                    = local.network_name
}

resource "google_compute_subnetwork" "apps" {
  name                     = "apps-${local.subnet_prefix}"
  ip_cidr_range            = "10.2.0.0/16"
  region                   = local.region
  network                  = google_compute_network.this.id
  private_ip_google_access = true
  secondary_ip_range = [{
    ip_cidr_range = "192.168.10.0/24"
    range_name    = "apps-${local.subnet_prefix}-1"
  }]
}


output "cfout" {
  value = {
    network = google_compute_network.this
    subnet  = google_compute_subnetwork.apps
  }
}
