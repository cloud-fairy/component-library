variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

variable "argocd_values" {
  description = "ArgoCD Helm Values"
  type        = any
  default     = {}
}
