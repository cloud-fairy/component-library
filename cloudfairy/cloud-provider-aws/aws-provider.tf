variable "properties" {
    type = any
}

output "cfout" {
  value = {
    projectId  = local.projectId
    region     = var.properties.region
    type       = "aws"
    account_id = var.properties.account_id
  }
}

locals {
    projectId = "cloudfairy-on-aws"
}

output "template" {
    value = <<EOF
provider "aws" {
  region     = "${var.properties.region}"
  access_key = "${var.properties.awsAccessKey}"
  secret_key = "${var.properties.awsSecretKey}"
}
EOF
}
