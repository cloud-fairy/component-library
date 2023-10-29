/**

This is a no-op terraform for local cloudfairy environment.

*/

variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

output "cfout" {
  value = {}
}
