variable config {
  type = any
}

variable "dependency" {
  type = any
}


data "aws_route53_zone" "domain" {
  name         = var.config.domain
  private_zone = false
}

data "aws_eks_cluster" "eks" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_id
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  # load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

locals {
  vpc_id      = var.global_config.vpc_id
}
module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.19.0"

  cluster_name = var.config.name

  # EKS Cluster VPC and Subnets
  vpc_id             = var.dependency.hackinfra_vpc.vpc_id
  private_subnet_ids = var.dependency.hackinfra_vpc.subnets.private

  # Cluster Security Group
  cluster_additional_security_group_ids = split(",",var.config.cluster_additional_security_group_ids)


  # EKS CONTROL PLANE VARIABLES
  cluster_version = var.config.k8s_version

  cluster_endpoint_public_access  = var.config.enable_public_access
  cluster_endpoint_private_access = true

  # EKS MANAGED NODE GROUPS
  managed_node_groups = var.config.managed_node_groups


  /* aws_auth_users */
  map_users = var.config.map_users
  map_roles = var.config.map_roles

  # EKS Application Teams
  platform_teams = var.config.platform_teams
  application_teams = var.config.application_teams

  #Custom Tags.
  /* tags = local.tags */
  node_security_group_additional_rules = {
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    # Recommended outbound traffic for Node groups
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    ingress_all_vpc = {
      description = "all VPC ingress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [var.dependency.hackinfra_vpc.cidr]
    }
    # Allows Control Plane Nodes to talk to Worker nodes on all ports. Added this to simplify the example and further avoid issues with Add-ons communication with Control plane.
    # This can be restricted further to specific port based on the requirement for each Add-on e.g., metrics-server 4443, spark-operator 8080, karpenter 8443 etc.
    # Change this according to your security requirements if needed
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # cluster_timeouts = {
  #   "create" = "30m",
  #   "update" = "60m",
  #   "delete" = "15m"
  # }

  eks_readiness_timeout = "1200"

}


output "cfout" {
  value = {
    name                   = module.eks.name
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
  sensitive = true
}
