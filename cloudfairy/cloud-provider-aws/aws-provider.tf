variable "properties" {
    type = any
}

locals {
    projectId               = "cloudfairy-on-aws-${random_string.suffix.result}"
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
    account_id             = var.properties.account_id
  }
}

output "template" {
  value = <<EOF
  provider "aws" {
    region                 = "${var.properties.region}"
    access_key             = "${var.properties.awsAccessKey}"
    secret_key             = "${var.properties.awsSecretKey}"
  }
EOF
}