variable properties {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

variable "autoscaler_version" {
  description = "Autoscaler chart version"
  type        = string
  default     = "9.28.0"
}

variable "autoscaler_enabled" {
  description = "Autoscaler Enabled"
  type        = bool
  default     = false
}

variable "external_dns_domain_filters" {
  description = "External-dns Domain filters."
  type        = list(string)
  default     = ["tikalk.dev"]
}