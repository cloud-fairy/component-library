variable "autoscaler_version" {
  description = "Autoscaler chart version"
  type        = string
  default     = "9.28.0"
}

variable "autoscaler_enabled" {
  description = "Autoscaler Enabled"
  type        = bool
  default     = true
}