locals {
    autoscaler_enabled = var.properties.name == "auto-scaler" ? true : false
}

// Install ec2 node Autoscaler
resource "helm_release" "cluster_autoscaler" {
  count = var.autoscaler_enabled ? 1 : 0

  name       = "aws-cluster-autoscaler"
  chart      = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  namespace  = "kube-system"
  version    = var.autoscaler_version
  timeout    = 600

  set {
    name  = "autoDiscovery.clusterName"
    value = data.aws_eks_cluster.eks.id
  }
  set {
    name  = "awsRegion"
    value = var.dependency.cloud_provider.region
  }
  set {
    name  = "cloudProvider"
    value = "aws"
  }
  set {
    name  = "rbac.create"
    value = true
  }
  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }
  set {
    name  = "rbac.serviceAccount.name"
    value = "eks-cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_autoscaler[0].this_iam_role_arn
  }
  depends_on = [
    module.eks
  ]
}

module "iam_assumable_role_autoscaler" {
  count = var.autoscaler_enabled ? 1 : 0

  source                        = "registry.terraform.io/terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "3.6.0"
  create_role                   = true
  role_name                     = format("eks-%s-cluster-autoscaler-irsa", data.aws_eks_cluster.eks.id)
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_autoscaler[0].arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:eks-cluster-autoscaler"]

  depends_on = [
    module.eks,
    aws_iam_policy.cluster_autoscaler
  ]
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.autoscaler_enabled ? 1 : 0

  name        = format("eks-%s-cluster-autoscaler", data.aws_eks_cluster.eks.id)
  description = format("EKS cluster-autoscaler policy for cluster %s", data.aws_eks_cluster.eks.id)
  policy      = data.aws_iam_policy_document.cluster_autoscaler.json

  depends_on = [
    module.eks,
    data.aws_iam_policy_document.cluster_autoscaler,
    data.aws_eks_cluster.eks
  ]
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid    = "clusterAutoscalerAll"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]

    resources = ["*"]
  }
}
