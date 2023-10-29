/**

This is a no-op terraform for local cloudfairy environment.

*/

variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

output "cfout" {
  value = {
    tags = {
      Terraform   = "true"
      Environment = var.project.environment_name
      Project     = var.project.project_name
      ProjectID   = var.project.project_name
    }
  }
}
