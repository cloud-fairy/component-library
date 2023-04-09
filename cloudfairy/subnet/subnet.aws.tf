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
  cidr_block = var.properties.block

  tags = {
    Name = var.properties.subnet_name
  }
}

output "cfout" {
  value = {
    network_name = var.dependency.network.name
    block        = var.properties.block
    subnet_id    = aws_subnet.main.id
  }
}
