variable "properties" {
  type = any
}

variable "project" {
  type = any
}

locals {
  projectId = "cf${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

output "cfout" {
  value = {
    projectId = local.projectId
    region    = var.project.CLOUD_REGION
    type      = "digitalocean"
  }
}

output "template" {
  value = <<EOF
terraform {
  required_providers {
      digitalocean = {
        source = "digitalocean/digitalocean"
        version = "2.34.1"
      }
    }
}

provider "digitalocean" {}

EOF
}
