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
  vpc_id            = var.dependency.network.id
  cidr_block        = replace(var.dependency.network.cidr, "/0\\.0/16/", var.properties.cidr)
  availability_zone = var.properties.az

  tags = {
    Name        = var.properties.subnet_name
    Terraform   = "true"
    Environment = var.project.environment_name
    Project     = var.project.project_name
    Component   = "subnet"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table_association" "nat_access" {
  subnet_id      = aws_subnet.main.id
  route_table_id = var.dependency.network.private_route_table_id
}

output "cfout" {
  value = {
    network_name = var.dependency.network.name
    cidr         = var.properties.cidr
    subnet_id    = aws_subnet.main.id
  }
}
