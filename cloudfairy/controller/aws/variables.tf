variable properties {
  type        = any
}

variable "dependency" {
  type        = any
}

variable "project" {
  type        = any
}

variable "external_dns_domain_filters" {
  description = "External-dns Domain filters."
  type        = list(string)
  default     = ["tikalk.dev"]
}