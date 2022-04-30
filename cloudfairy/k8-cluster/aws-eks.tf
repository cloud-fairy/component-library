variable "config" {
  type = any
}

variable "dependency" {
  type = any
}

locals {
  region = var.dependency.cloud_provider.region
  accountId = var.dependency.cloud_provider.account_id
}

# HACK to enforce kube log in

data "aws_eks_cluster" "default" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}

### AWS ROLE

resource "aws_iam_role" "cluster_role" {
  name = "cloudfairy-cluster-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "eks.amazonaws.com"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "ArnLike": {
        "aws:SourceArn": "arn:aws:eks:${local.region}:${local.accountId}:cluster/${var.config.cluster_name}"
      }
    }
  }]
}
POLICY
}

# {
#     "Effect": "Allow",
#     "Action": [
#       "ecr:BatchCheckLayerAvailability",
#       "ecr:BatchGetImage",
#       "ecr:GetLifecyclePolicy",
#       "ecr:GetDownloadUrlForLayer",
#       "ecr:GetAuthorizationToken"
#     ]
#   }

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.cluster_role.name
}

resource "aws_iam_role_policy_attachment" "resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role = aws_iam_role.cluster_role.name
}

### NETWORKING/SECURITY GROUP

resource "aws_security_group" "worker_group_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id = var.dependency.vpc.vpcId

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"

    cidr_blocks = [
      "10.0.0.0/8"
    ]
  }
}

resource "aws_security_group" "worker_group_two" {
  name_prefix = "worker_group_mgmt_two"
  vpc_id = var.dependency.vpc.vpcId
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"

    cidr_blocks = [
      "192.168.0.0/16"
    ]
  }
}

resource "aws_security_group" "worker_group_all" {
  name_prefix = "worker_group_mgmt_all"
  vpc_id = var.dependency.vpc.vpcId
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16"
    ]
  }
}

### EKS CLUSTER

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "18.20.2"
  
  cluster_name = var.config.cluster_name
  subnet_ids = var.dependency.vpc.vpc.private_subnets

  vpc_id = var.dependency.vpc.vpcId

  eks_managed_node_group_defaults = {
    root_volume_type = "gp2"
  }

  eks_managed_node_groups = {
    worker_group_one = {
      min_size = 1
      max_size = 1
      desired_size = 1
      instance_type                 = "ts2.small"
      additional_security_group_ids = [aws_security_group.worker_group_one]
    },
    woker_group_two = {
      min_size = 1
      max_size = 2
      desired_size = 1
      instance_type                 = "ts2.medium"
      additional_security_group_ids = [aws_security_group.worker_group_two]
    }
  }

  # create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  tags = {
    Cloudfairy = "True"
  }

}

data "aws_eks_cluster" "cluster" {
  depends_on = [module.eks]
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  depends_on = [module.eks]
  name = module.eks.cluster_id
}

data "null_data_source" "lazy" {
  depends_on = [module.eks]
  inputs = {
    host = module.eks.cluster_endpoint
    # kubectl_config = module.eks.kubeconfig
    # security_group_id = module.eks.security_group_id
    arn = module.eks.cluster_arn
    client_cert = module.eks.cluster_certificate_authority_data
    cluster_endpoint = module.eks.cluster_endpoint
    # config_map_aws_auth = module.eks.config_map_aws_auth
    cluster_id = module.eks.cluster_id
  }
}

output "cfout" {
  depends_on = [module.eks.outputs]
  sensitive = true
  value = {
      id = data.null_data_source.lazy.outputs.cluster_id
      self_link = ""
      # endpoint = module.eks.cluster_endpoint
      endpoint = data.null_data_source.lazy.outputs.cluster_endpoint
      # host = module.eks.cluster_endpoint
      host = data.null_data_source.lazy.outputs.host
      ca_cert = data.aws_eks_cluster_auth.cluster.token
      token = data.aws_eks_cluster_auth.cluster.token
      # client_cert = module.eks.cluster_certificate_authority_data
      client_cert = data.null_data_source.lazy.outputs.client_cert
      # arn = module.eks.cluster_arn
      arn = data.null_data_source.lazy.outputs.arn
      # security_group_id = module.eks.cluster_security_group_id
      # security_group_id = data.null_data_source.lazy.outputs.cluster_security_group_id
      # kubectl_config = data.null_data_source.lazy.outputs.kubectl_config
      # config_map_aws_auth = module.eks.config_map_aws_auth
      # config_map_aws_auth = data.null_data_source.lazy.outputs.config_map_aws_auth
      cluster_name = var.config.cluster_name
  }
}