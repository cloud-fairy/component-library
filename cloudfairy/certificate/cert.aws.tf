variable "properties" {
  type                      = any
}

variable "dependency" {
  type                      = any
}

variable "project" {
  type                      = any
}

provider "aws" {
  alias                     = "acm"
  region                    = var.dependency.cloud_provider.region != var.properties.region ? var.properties.region : var.dependency.cloud_provider.region
}

locals {
  # Removing trailing dot from domain - just to be sure :)
  domain_name               = lower("${local.tags.Project}.${local.zone_name}")
  zone_name                 = var.dependency.cloud_provider.hosted_zone
  hostname                  = lower("*.${local.tags.Project}.${local.zone_name}")

  zone_id                   = try(data.aws_route53_zone.this.zone_id, null)
  tags                      = var.dependency.base.tags
}

data "aws_route53_zone" "this" {
  name                      = local.zone_name
  private_zone              = false
}

module "acm" {
  count                     = local.zone_id != null ? 1 : 0

  source                    = "terraform-aws-modules/acm/aws"
  version                   = "4.3.2"

  providers                 = {
    aws                     = aws.acm
  }

  domain_name               = local.domain_name
  zone_id                   = local.zone_id

  subject_alternative_names = [
    "${local.hostname}",
  ]

  tags                      = local.tags
}

output "cfout" {
  value                     = {
    name                    =  var.properties.hostname
    domain                  =  local.domain_name
    arn                     =  module.acm[0].acm_certificate_arn
    status                  =  module.acm[0].acm_certificate_status
    zone_id                 =  local.zone_id
    zone_name               =  local.zone_name
  }
}