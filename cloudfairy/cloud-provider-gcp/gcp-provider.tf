variable "properties" {
  type = any
}

output "cfout" {
  value = {
    projectId = local.projectId
    region    = var.properties.region
    type      = "gcp"
    _c        = var.properties.credentials
  }
}

locals {
  projectId = var.properties.projectId
}

output "template" {
  value = <<EOF
provider "google" {
  project     = "${local.projectId}"
  region      = "${var.properties.region}"
  credentials = "${var.properties.credentials}"
}
EOF
}
