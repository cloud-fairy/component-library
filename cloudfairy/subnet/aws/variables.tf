variable "properties" {
  type = any

  # Validating IP cidr is in correct format
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\/[0-9]{1,2}$", var.properties.cidr))
    error_message = "CIDR Block is incorrect"
  }
  # Validating AZ is in the correct format
  validation {
    condition     = can(regex("^(us|eu|sa|ap|ca|af|me)-[a-z]+-\\d[a-z]$", var.properties.az))
    error_message = "Availability Zone is incorrect"
  }
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}