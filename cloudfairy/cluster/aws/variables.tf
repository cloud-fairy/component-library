variable properties {
  type        = any
}

variable "dependency" {
  type        = any
}

variable "project" {
  type        = any
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

variable "service_account" {
  description = "Name of irsa role service account name"
  type        = string
  default     = "cloudfairysa"
}

variable "instance_type" {
  description = "Name of irsa role service account name"
  type        = string
  default     = "t3.large"
}