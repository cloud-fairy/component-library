variable "properties" {
  type = any

  validation {
    condition     = !anytrue([
      var.properties.name == "mysql",
      var.properties.name == "check"
    ])
    error_message = "DB Name cannot be 'mysql'|'check'"
  }
  validation {
    condition     = can(regex("^(\\d)+$", var.properties.size)) 
    error_message = "DB Size must be an integer"
  }
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
} 

variable "mysql_version" {
  description = "MySQL Engine version"
  type        = string
  default     = "8.0.32"
}

variable "postgresql_version" {
  description = "PostgreSQL Engine version"
  type        = string
  default     = "14.7"
}

variable "mariadb_version" {
  description = "MariaDB Engine version"
  type        = string
  default     = "10.6.12"
}

variable "aurora_version" {
  description = "Aurora MySQL Engine version"
  type        = string
  default     = "5.7.mysql_aurora.2.11.2"
}

variable "deafult_instance_class" {
  description = "RDS Instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "aurora_instance_class" {
  description = "RDS Instance class"
  type        = string
  default     = "db.r5.large"
}