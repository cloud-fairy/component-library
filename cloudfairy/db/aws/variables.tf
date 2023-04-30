variable "properties" {
  type = any
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
  default     = "14.6-R1"
}

variable "mariadb_version" {
  description = "MariaDB Engine version"
  type        = string
  default     = "10.6.12"
}

variable "instance_class" {
  description = "RDS Instance class"
  type        = string
  default     = "db.t3.micro"
}