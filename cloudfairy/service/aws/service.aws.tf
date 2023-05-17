variable "properties" {
  # service_name
  # repo_url
  type                 = any
}

variable "project" {
  # environment_name
  type                 = any
}

variable "dependency" {
  # cloud_provider
  # cluster
  type                 = any
}

variable "connector" {
  # cloudfairy_k8_microservice_to_managed_sql : any[]
  type                 = any
}

locals {
  tags = {
    Terraform          = "true"
    Environment        = var.project.environment_name
    Project            = var.project.project_name
    ProjectID          = var.dependency.cloud_provider.projectId
  }
}

resource "aws_ecr_repository" "docker" {
  name                 = var.properties.service_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push       = true
  }
  tags                 = local.tags
}

output "cfout" {
  value = {
    repository_url     = aws_ecr_repository.docker.repository_url
  }
}