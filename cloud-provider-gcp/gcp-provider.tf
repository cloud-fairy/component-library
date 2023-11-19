variable "properties" {
  type = any
}

variable "project" {
  type = any
}

output "cfout" {
  value = {
    projectId = local.projectId
    region    = var.project.CLOUD_REGION
    type      = "gcp"
  }
}

locals {
  projectId = var.project.PROJECT_ID
}

output "template" {
  value = <<EOF
provider "google" {
  project     = "${local.projectId}"
  region      = "${var.project.CLOUD_REGION}"
}
EOF
}
