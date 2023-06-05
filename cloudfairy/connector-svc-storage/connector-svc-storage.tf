variable "properties" {
  type                 = any
}

variable "dependency" {
  type                 = object({
    from_module        = any
  })
}

locals {
    bucket             = var.dependency.from_module.storage_name
}

output "cfout" {
  value = [
    {
      name             = var.properties.bucketname
      value            = local.bucket
    }
  ]
}
