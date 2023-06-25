variable properties {
  type        = any
}

variable "dependency" {
  type        = any
}

variable "project" {
  type        = any
}

variable "connector" {
  type        = any
}

variable "external_dns_domain_filters" {
  description = "External-dns Domain filters."
  type        = list(string)
  default     = ["tikalk.dev"]
}

variable "enable_load_balancer" {
  description = "Should Load-Balancer operator be enabled"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Should External-DNS operator be enabled"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Should Cert-Manager operator be enabled"
  type        = bool
  default     = false
}

variable "enable_external_secrets" {
  description = "Should External-Secrets operator be enabled"
  type        = bool
  default     = true
}