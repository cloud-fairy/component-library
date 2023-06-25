locals {
  subnets_count                   =  length(split(",", (jsonencode(data.aws_subnets.private.*.ids[0][*]))))
  create_cluster                  =  local.subnets_count > 1 ? true : false    # Two subnets required to create EKS Cluster
  cluster_name                    =  "${var.properties.name}-${local.tags.Environment}-${local.tags.Project}-${local.tags.ProjectID}"
  tags                            =  var.dependency.base.tags
}

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.20.0"
    }
    external = {
      source = "hashicorp/external"
      version = "2.3.1"
    }
  }
}

data "aws_eks_cluster" "eks" {
  name                            = local.cluster_name

  depends_on                      = [
    module.eks
  ]
}

data "aws_eks_cluster_auth" "eks" {
  name                            = data.aws_eks_cluster.eks.name

  depends_on                      = [
    module.eks
  ]
}

data "aws_subnets" "private" {
  filter {
    name                          = "vpc-id"
    values                        = [var.dependency.network.id]
  }
  filter {
    name                          =  "tag:type"
    values                        = ["Private"]
  }
}

module "eks" {
  create                          = local.create_cluster
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "19.13.0"

  cluster_name                    = local.cluster_name
  cluster_version                 = var.properties.k8s_version
  tags                            = local.tags

  # EKS Cluster VPC and Subnets
  vpc_id                          = var.dependency.network.id
  subnet_ids                      = data.aws_subnets.private.ids
  cluster_endpoint_public_access  = var.properties.enable_public_access
  iam_role_use_name_prefix        = false

  # EKS Addons
  cluster_addons                  = {
    coredns                       = {}
    kube-proxy                    = {}
    vpc-cni                       = {}
  }

  # Cloudwatch log group
  create_cloudwatch_log_group     = local.create_cluster
  eks_managed_node_group_defaults = {
       ami_type                   = "AL2_x86_64"
       iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    "${var.properties.name}"                           = {
      instance_types              = [var.instance_type]
      #capacity_type               = "SPOT"

      min_size                    = 2
      max_size                    = 4
      desired_size                = 2
    }
  }

  node_security_group_additional_rules = {
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
    ingress_self_all              = {
      description                 = "Node to node all ports/protocols"
      protocol                    = "-1"
      from_port                   = 0
      to_port                     = 0
      type                        = "ingress"
      self                        = true
    }

    # Recommended outbound traffic for Node groups
    egress_all = {
      description                 = "Node all egress"
      protocol                    = "-1"
      from_port                   = 0
      to_port                     = 0
      type                        = "egress"
      cidr_blocks                 = ["0.0.0.0/0"]
      ipv6_cidr_blocks            = ["::/0"]
    }
    ingress_all_vpc = {
      description                 = "all VPC ingress"
      protocol                    = "-1"
      from_port                   = 0
      to_port                     = 0
      type                        = "ingress"
      cidr_blocks                 = [var.dependency.network.cidr]
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

  cluster_timeouts = {
    "create" = "30m",
    "update" = "60m",
    "delete" = "15m"
  }
}

provider "helm" {
  kubernetes {
    host                             = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate           = base64decode(data.aws_eks_cluster.eks.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubectl" {
  host                              = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate            = base64decode(data.aws_eks_cluster.eks.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    command     = "aws"
  }
}

resource "null_resource" "kubectl" {
    triggers = {
      always_run = timestamp()
    }
    provisioner "local-exec" {
        command = "aws eks --region ${var.dependency.cloud_provider.region} update-kubeconfig --name ${data.aws_eks_cluster.eks.name}"
    }
}

output "cfout" {
  value = {
    name                    = data.aws_eks_cluster.eks.name
    host                    = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate  = base64decode(data.aws_eks_cluster.eks.certificate_authority.0.data)
    token                   = data.aws_eks_cluster_auth.eks.token
    oidc_provider           = module.eks.oidc_provider
    oidc_provider_arn       = module.eks.oidc_provider_arn
    cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
    cluster_version         = var.properties.k8s_version
    eks                     = module.eks
    irsa_role_arn           = module.iam_assumable_role_admin.iam_role_arn
    service_account         = local.service_account
  }
  sensitive = true
}

output "error" {
  value     = local.create_cluster == false ? "Must have at least two subnets in two AZs in order to create EKS Cluster" : ""
}
