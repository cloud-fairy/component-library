variable "properties" {
  type                      = any
}

locals {
  projectId                 = "cf${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length                    = 8
  special                   = false
}

output "cfout" {
  value                    = {
    projectId              = local.projectId
    region                 = var.properties.region
    type                   = "aws"
  }
}

output "template" {
  value = <<EOF
  provider "aws" {
    region                 = "${var.properties.region}"
  }
EOF
}