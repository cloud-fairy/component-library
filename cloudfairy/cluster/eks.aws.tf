variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.12.0"

  cluster_name    = var.properties.cluster_name
  cluster_version = "1.24"

  vpc_id                         = var.dependency.network.id
  subnet_ids                     = var.dependency.network.private_subnets
  cluster_endpoint_public_access = var.dependency.network.enable_public_access

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]
      capacity_type  = "SPOT"

      min_size     = 2
      max_size     = 3
      desired_size = 3
    }
  }

  tags = {
    Terraform   = "true"
    Environment = var.project.environment_name
    Project     = var.project.project_name
  }
}