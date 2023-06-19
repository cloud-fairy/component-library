variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type                     = any
}

locals {
  tags = {
    Terraform                 = "true"
    Environment               = var.project.environment_name
    Project                   = var.project.project_name
    ProjectID                 = var.dependency.cloud_provider.projectId
  }
}

output "cfout" {
  value = {
    tags      = local.tags
  }
}