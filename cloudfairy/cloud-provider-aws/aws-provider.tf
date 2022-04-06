variable "config" {
  type = any
}

output "cfout" {
  value = {
    projectId = local.projectId
    region    = var.config.region
    type      = "aws"
  }
}

locals {
  projectId = "cloudfairy-on-aws"
}

output "template" {
  value = <<EOF
provider "aws" {
  region     = "${var.config.region}"
  access_key = "${var.config.awsAccessKey}"
  secret_key = "${var.config.awsSecretKey}"
}
EOF
}
