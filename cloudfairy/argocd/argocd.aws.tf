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
  argocd_applications = {
    "${var.properties.appname}" = {
      path               = var.properties.path
      repo_url           = var.properties.repo
      add_on_application = true
    }
  }

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
    argocd    = module.argocd.argocd.release_metadata
  }
}