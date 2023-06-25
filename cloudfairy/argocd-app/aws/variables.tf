variable "properties" {
  type = any

  validation {
    condition     = can(regex("^(git|https)", var.properties.repo)) 
    error_message = "Repository URL must start with 'https' or 'git'"
  }
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}