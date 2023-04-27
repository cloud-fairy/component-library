variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

locals {
  # Use existing (via data source) or create new zone (will fail validation, if zone is not reachable)
  use_existing_route53_zone = true

  # Removing trailing dot from domain - just to be sure :)
  domain_name = trim(regex("\\..*$", var.properties.hostname), ".")

  zone_id = try(data.aws_route53_zone.this[0].zone_id, aws_route53_zone.this[0].zone_id, null)
}

data "aws_route53_zone" "this" {
  count = local.use_existing_route53_zone ? 1 : 0

  name         = local.domain_name
  private_zone = false
}

resource "aws_route53_zone" "this" {
  count = !local.use_existing_route53_zone ? 1 : 0

  name = local.domain_name
}

module "acm" {
  count = local.zone_id != null ? 1 : 0

  source  = "terraform-aws-modules/acm/aws"
  version = "4.3.2"

  domain_name = local.domain_name
  zone_id     = local.zone_id

  subject_alternative_names = [
    "${var.properties.hostname}",
  ]

  tags = {
    Name = local.domain_name
  }
}

output "cfout" {
  value = {
    name    =  var.properties.hostname
    domain  =  local.domain_name
    arn     =  module.acm[0].acm_certificate_arn
    status  =  module.acm[0].acm_certificate_status
  }
}