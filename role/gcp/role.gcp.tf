/**

This is a no-op terraform for local cloudfairy environment.

*/

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
  gcp_project          = var.project.PROJECT_ID
  project_name         = var.project.project_name
  env_name             = var.project.environment_name
  service_account_name = try(var.properties.service_account_name, "cloudfairy-default")
  sa_fullname          = "${local.project_name}${local.env_name}${local.service_account_name}"
  all_service_account_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader"
  ]
}

resource "google_service_account" "service_account" {
  project      = local.gcp_project
  account_id   = local.sa_fullname
  display_name = "Cloudfairy Managed Service Account - ${local.env_name}"
}

resource "google_project_iam_member" "service_account_roles" {
  for_each = toset(local.all_service_account_roles)

  project = var.project.PROJECT_ID
  role    = each.value
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

output "cfout" {
  value = {
    service_account = google_service_account.service_account
    iam_member      = google_project_iam_member.service_account_roles
  }
}
