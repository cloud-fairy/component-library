variable "properties" {
  type = any
}

output "cfout" {
  value = {
    region = "local"
    type   = "local"
  }
}

output "template" {
  value = <<EOF
terraform {
  required_providers {
    k3d = {
      source = "pvotal-tech/k3d"
      version = "0.0.7"
    }
  }
}
provider "k3d" {}
EOF
}
