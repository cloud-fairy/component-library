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
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table_association" "nat_access" {
  subnet_id      = aws_subnet.main.id
  route_table_id = var.dependency.network.private_route_table_id
}

output "cfout" {
  value = {
    name      = var.properties.subnet_name
    cidr      = var.properties.cidr
    subnet_id = aws_subnet.main.id
    vpc_id    = var.dependency.network.id
  }
}
