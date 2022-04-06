variable "config" {
  type = any
}

output "cfout" {
  value = {
    projectId = local.projectId
    region    = var.config.region
    type      = "gcp"
    _c        = var.config.credentials
  }
}

locals {
  projectId = var.config.projectId
}

output "template" {
  value = <<EOF
provider "google" {
  project     = "${local.projectId}"
  region      = "${var.config.region}"
  credentials = "${var.config.credentials}"
}
EOF
}
