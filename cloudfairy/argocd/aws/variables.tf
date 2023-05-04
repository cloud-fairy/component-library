variable "properties" {
  type = any

  # Validating ArgoCD hostname is proper DNS name
  validation {
    condition     = can(regex("^[a-z-]+[0-9]*.*(\\.)[0-9a-z-]+((\\.)[0-9a-z-]+)*", var.properties.hostname))
    error_message = "ArgoCD hostname is invalid DNS name"
  }
  validation {
    condition     = can(regex("^(arn:)(aws:)(acm:)(.*)", var.properties.certificate_arn))
    error_message = "Certificate ARN is invalid"
  }
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}