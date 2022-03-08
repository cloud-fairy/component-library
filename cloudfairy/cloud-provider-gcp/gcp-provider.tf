# Public website cloudfairy module

# dependencies:
# - cloudfairy/cloud-provider

variable "config" {
  type = any
}

# provider "google" {
#   project     = var.config.projectId
#   region      = var.config.region
#   credentials = var.config.credentials # "./sa.json"
# }

output "cfout" {
  value = {
    projectId = var.config.projectId
    region    = var.config.region
    type      = "gcp"
  }
}

output "template" {
  value = <<EOF
provider "google" {
  project     = "${var.config.projectId}"
  region      = "${var.config.region}"
  credentials = "${var.config.credentials}"
}
EOF
}
