variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

resource "aws_subnet" "main" {
  vpc_id     = var.dependency.network.id
  cidr_block = replace(var.dependency.network.cidr, "/0\\.0/16/", var.properties.cidr)

  tags = {
    Name = var.properties.subnet_name
  }
}

output "cfout" {
  value = {
    network_name = var.dependency.network.name
    cidr         = var.properties.cidr
    subnet_id    = aws_subnet.main.id
  }
}
