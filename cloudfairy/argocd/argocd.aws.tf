variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

# Configuring required providers
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.3.2"
    }
    bcrypt = {
      source  = "viktorradnai/bcrypt"
      version = ">= 0.1.2"
    }
  }
}

provider "kubernetes" {
  host                   = var.dependency.cluster.host
  cluster_ca_certificate = var.dependency.cluster.cluster_ca_certificate
  token                  = var.dependency.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = var.dependency.cluster.host
    cluster_ca_certificate = var.dependency.cluster.cluster_ca_certificate
    token                  = var.dependency.cluster.token
  }
}

provider "bcrypt" {}

module "load_balancer_controller" {
  source                           = "DNXLabs/eks-lb-controller/aws"
  version                          = "0.7.0"
  cluster_identity_oidc_issuer     = var.dependency.cluster.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = var.dependency.cluster.oidc_provider_arn
  cluster_name                     = var.dependency.cluster.name
}

module "eks-external-dns" {
  source  = "lablabs/eks-external-dns/aws"
  version = "1.1.1"

  cluster_identity_oidc_issuer 	    = var.dependency.cluster.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn  = var.dependency.cluster.oidc_provider_arn
}

module "argocd" {
  source  = "github.com/aws-ia/terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id       = var.dependency.cluster.name
  eks_cluster_endpoint = var.dependency.cluster.host
  eks_oidc_provider    = var.dependency.cluster.oidc_provider
  eks_cluster_version  = var.dependency.cluster.cluster_version

  enable_argocd = true
  # This example shows how to set default ArgoCD Admin Password using SecretsManager with Helm Chart set_sensitive values.
  argocd_helm_config = {
    set_sensitive = [
      {
        name  = "configs.secret.argocdServerAdminPassword"
        value = bcrypt_hash.argo.id
      }
    ]
    set = [
      {
        name  = "server.service.type"
        value = "LoadBalancer"
      },
      {
        name  = "server.service.annotations\\.beta\\.kubernetes\\.io/aws-load-balancer-proxy-protocol"
        value = "*"
      },
      {
        name  = "server.service.annotations.service\\.beta\\.kubernetes.io/aws-load-balancer-scheme"
        value = "internet-facing"
      },
      {
        name  = "server.service.annotations.service\\.beta\\.kubernetes.io/aws-load-balancer-type"
        value = "external"
      },
      {
        name  = "server.ingress.enabled"
        value = true
      },
      {
        name  = "server.ingress.ingressClassName"
        value = "alb"
      },
      {
        name  = "server.ingress.annotations.external-dns.alpha\\.kubernetes.io/hostname"
        value = "argocd-fairyeks.tikalk.dev"
      },
      {
        name  = "server.ingress.annotations.alb.ingress\\.kubernetes.io/scheme"
        value = "internet-facing"
      },
      {
        name  = "server.ingress.annotations.alb.ingress\\.kubernetes.io/target-type"
        value = "ip"
      },
      {
        name  = "server.ingress.annotations.alb.ingress\\.kubernetes.io/group.name"
        value = "argocd"
      },
      {
        name  = "server.ingress.annotations.alb.ingress\\.kubernetes.io/group.order"
        value = "4"
      },
      {
        name  = "server.ingress.annotations.alb.ingress\\.kubernetes.io/group.idle-timeout-seconds"
        value = "60"
      },
      {
        name  = "server.ingress.annotations.alb.ingress\\.kubernetes.io/backend-protocol"
        value = "HTTPS"
      }
    ]
  # # Enable ingress for Argo CD server
  # "server.ingress.enabled" = "true"
  # # Set the ingress class name to use for Argo CD server
  # "server.ingress.annotations.alb.ingress.kubernetes.io/ingress.class" = "alb"
  # # Set the ingress hostname to use for Argo CD server
  # "server.ingress.annotations.external-dns.alpha.kubernetes.io/hostname" = "argocd-fairyeks.tikalk.dev"
  # # Set the ingress scheme to use for Argo CD server
  # "server.ingress.annotations.alb.ingress.kubernetes.io/scheme" = "internet-facing"
  # # Set the target type for the ALB ingress controller
  # "server.ingress.annotations.alb.ingress.kubernetes.io/target-type" = "ip"
  # # Set the health check path for the ALB ingress controller
  # "server.ingress.annotations.alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
  # # Set the listen ports for the ALB ingress controller
  # "server.ingress.annotations.alb.ingress.kubernetes.io/listen-ports" = jsonencode([{
  #   HTTP  = 80
  #   HTTPS = 443
  # }])
  # # Set the group name for the ALB ingress controller
  # "server.ingress.annotations.alb.ingress.kubernetes.io/group.name" = "argocd"
  # # Set the group order for the ALB ingress controller
  # "server.ingress.annotations.alb.ingress.kubernetes.io/group.order" = "10"
  # # Set the idle timeout for the ALB ingress controller
  # "server.ingress.annotations.alb.ingress.kubernetes.io/group.idle-timeout-seconds" = "60"
  # # Set the load balancer attributes for the ALB ingress controller
  # "server.ingress.annotations.alb.ingress.kubernetes.io/load-balancer-attributes" = jsonencode({
  #   "idle_timeout.timeout_seconds" = 60
  # })
  # # Set the tags for the ALB ingress controller
  # "server.ingress.annotations.alb.ingress.kubernetes.io/tags" = jsonencode({
  #   Name = "argocd"
  # })
  # # Set the backend protocol for the ALB ingress controller
  # "server.ingress.annotations.alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"
  }

  keda_helm_config = {
    values = [
      {
        name  = "serviceAccount.create"
        value = "false"
      }
    ]
  }

  argocd_manage_add_ons = true # Indicates that ArgoCD is responsible for managing/deploying add-ons
  argocd_applications = var.properties.appname != "" ? {
    "${var.properties.appname}" = {
      path               = var.properties.path
      repo_url           = var.properties.repo
      add_on_application = true
    }
  } : {}

  # Add-ons
  # enable_amazon_eks_aws_ebs_csi_driver = true
  # enable_aws_for_fluentbit             = true
  # # Let fluentbit create the cw log group
  # aws_for_fluentbit_create_cw_log_group = false
  # enable_cert_manager                   = true
  # enable_cluster_autoscaler             = true
  # enable_karpenter                      = true
  # enable_keda                           = true
  # enable_metrics_server                 = true
  # enable_prometheus                     = true
  # enable_traefik                        = true
  # enable_vpa                            = true
  # enable_yunikorn                       = true
  # enable_argo_rollouts                  = true

  tags = {
    Terraform   = "true"
    Environment = var.project.environment_name
    Project     = var.project.project_name
  }
}

#---------------------------------------------------------------
# ArgoCD Admin Password credentials with Secrets Manager
# Login to AWS Secrets manager with the same role as Terraform to extract the ArgoCD admin password with the secret name as "argocd"
#---------------------------------------------------------------
resource "random_password" "argocd" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Argo requires the password to be bcrypt, we use custom provider of bcrypt,
# as the default bcrypt function generates diff for each terraform plan
resource "bcrypt_hash" "argo" {
  cleartext = random_password.argocd.result
}

# Adding random_string so that each secret would be unique and duplicates would be prevented 
resource "random_string" "suffix" {
  length  = 8
  special = false
}

resource "aws_secretsmanager_secret" "argocd" {
  name                    = format("argocd-%s-%s-%s", var.project.project_name, var.project.environment_name, random_string.suffix.result)
  description             = format("ArgoCD Admin Secret for %s in %s environment", var.project.project_name, var.project.environment_name)
  recovery_window_in_days = 0 # Set to zero for this example to force delete during Terraform destroy
}

resource "aws_secretsmanager_secret_version" "argocd" {
  secret_id     = aws_secretsmanager_secret.argocd.id
  secret_string = random_password.argocd.result
}

output "cfout" {
  value = {
    chart         = module.argocd.argocd.release_metadata[0].chart
    app_version   = module.argocd.argocd.release_metadata[0].app_version
    namespace     = module.argocd.argocd.release_metadata[0].namespace
  }
}