# Configuring required providers
terraform {
  required_providers {
    random                   = {
      source                 = "hashicorp/random"
      version                = "3.3.2"
    }
    bcrypt = {
      source                 = "viktorradnai/bcrypt"
      version                = ">= 0.1.2"
    }
    helm                     = {
      source                 = "hashicorp/helm"
      version                = "2.9.0"
    }
    kubernetes               = {
      source                 = "hashicorp/kubernetes"
      version                = "2.20.0"
    }
    kubectl                  = {
      source                 = "gavinbunney/kubectl"
      version                = "1.14.0"
    }
  }
}

provider "kubernetes" {
  host                       =  var.dependency.cluster.host
  cluster_ca_certificate     = var.dependency.cluster.cluster_ca_certificate
  exec {
    api_version              = "client.authentication.k8s.io/v1beta1"
    args                     = ["eks", "get-token", "--cluster-name", var.dependency.cluster.name]
    command                  = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                     = var.dependency.cluster.host
    cluster_ca_certificate   = var.dependency.cluster.cluster_ca_certificate
    
    exec {
      api_version            = "client.authentication.k8s.io/v1beta1"
      args                   = ["eks", "get-token", "--cluster-name", var.dependency.cluster.name]
      command                = "aws"
    }
  }
}

provider "kubectl" {
  host                       = var.dependency.cluster.host
  cluster_ca_certificate     = var.dependency.cluster.cluster_ca_certificate
  exec {
    api_version              = "client.authentication.k8s.io/v1beta1"
    args                     = ["eks", "get-token", "--cluster-name", var.dependency.cluster.name]
    command                  = "aws"
  }
}

provider "bcrypt" {}

locals {
    argocd_values            = [
    <<-EOF
    configs:
      credentialTemplates:
        ssh-creds:
          url: "${local.ssh_repo_url}"
      knownHosts:
        data:
          ssh_known_hosts: |
               "${local.repo_host} ${var.properties.ssh_publickey}" 
    controller:
      enableStatefulSet: true
    redis-ha:
      enabled: false
    repoServer:
      autoscaling:
        enabled: true
        minReplicas: 2
    server:
      service:
        # needed for alb
        type: NodePort
      extraArgs:
        - --insecure
      autoscaling:
        enabled: true
        minReplicas: 1
      ingress:
        enabled: true
        hosts: ["${local.hostname}"]
        extraPaths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ssl-redirect
                port:
                  name: use-annotation
        annotations:
          alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "Path": "/#{path}", "Query": "#{query}", "StatusCode": "HTTP_301"}}'
          kubernetes.io/ingress.class: alb
          alb.ingress.kubernetes.io/target-type: ip
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/group.name: ${lower("${local.tags.Project}-${local.tags.Environment}")}
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80},{"HTTPS": 443}]'
          alb.ingress.kubernetes.io/certificate-arn: "${var.dependency.certificate.arn}"
          external-dns.alpha.kubernetes.io/hostname: "${local.hostname}"
    EOF
    ]
    tags                     = {
      Terraform              = "true"
      Environment            = var.project.environment_name
      Project                = var.project.project_name
      ProjectID              = var.dependency.cloud_provider.projectId
    }

    ssh_repo_url             = format("git@%s", replace(regex("(?:https:\\/\\/)(([0-9A-Za-z_\\-(\\.)]+)\\/([0-9A-Za-z_-(\\.)]+))(?:.*)$", var.properties.repo)[0], "/", ":"))
    repo_host                = join("", regex("(?:https:\\/\\/)([0-9A-Za-z_\\-(\\.)]+)(?:\\/)(?:.*)$", var.properties.repo))
    zone_name                = var.dependency.cloud_provider.hosted_zone
    hostname                 = lower("argocd-${local.tags.Environment}-${local.tags.ProjectID}.${local.tags.Project}.${local.zone_name}")
}

module "argocd" {
  source                     = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.32.1"

  eks_cluster_id             = var.dependency.cluster.name
  eks_cluster_endpoint       = var.dependency.cluster.host
  eks_oidc_provider          = var.dependency.cluster.oidc_provider
  eks_cluster_version        = var.dependency.cluster.cluster_version

  enable_argocd              = true
  # This example shows how to set default ArgoCD Admin Password using SecretsManager with Helm Chart set_sensitive values.
  argocd_helm_config         = {
    set_sensitive            = [
      {
        name  = "configs.secret.argocdServerAdminPassword"
        value = bcrypt_hash.argo.id
      }
    ]
    values = local.hostname != "" ? local.argocd_values : []    # No Ingress configuration if hostname is not set
  }

  keda_helm_config           = {
    values                   = [
      {
        name                 = "serviceAccount.create"
        value                = "false"
      }
    ]
  }

  argocd_manage_add_ons      = true # Indicates that ArgoCD is responsible for managing/deploying add-ons
  argocd_applications        = var.properties.appname != "" ? {
    "${var.properties.appname}" = {
      path                   = var.properties.repo_type != "chart" ? var.properties.path : var.properties.repo_type
      repo_url               = local.ssh_repo_url
      add_on_application     = true
    }
  } : {}

  tags                       = local.tags
}

#---------------------------------------------------------------
# ArgoCD Admin Password credentials with Secrets Manager
# Login to AWS Secrets manager with the same role as Terraform to extract the ArgoCD admin password with the secret name as "argocd"
#---------------------------------------------------------------
resource "random_password" "argocd" {
  length                     = 16
  special                    = true
  override_special           = "!#$%&*()-_=+[]{}<>:?"
}

# Argo requires the password to be bcrypt, we use custom provider of bcrypt,
# as the default bcrypt function generates diff for each terraform plan
resource "bcrypt_hash" "argo" {
  cleartext                  = random_password.argocd.result
}

# Adding random_string so that each secret would be unique and duplicates would be prevented 
resource "random_string" "suffix" {
  length                     = 8
  special                    = false
}

resource "aws_secretsmanager_secret" "argocd" {
  name                       = format("argocd-%s-%s-%s", var.project.project_name, var.project.environment_name, random_string.suffix.result)
  description                = format("ArgoCD Admin Secret for %s in %s environment", var.project.project_name, var.project.environment_name)
  recovery_window_in_days    = 0 # Set to zero for this example to force delete during Terraform destroy

  depends_on                 = [ module.argocd ]
}

resource "aws_secretsmanager_secret_version" "argocd" {
  secret_id                  = aws_secretsmanager_secret.argocd.id
  secret_string              = random_password.argocd.result
}

# Creating secret in order to be able to authenticate with repo server
resource "kubectl_manifest" "ingress_argocd" {
  yaml_body  = templatefile("${path.module}/repo_secret.yaml", { repo_url = "${local.ssh_repo_url}"})

  depends_on = [
          module.argocd
  ]
}

output "cfout" {
  value                      = { 
    chart                    = module.argocd.argocd.release_metadata[0].chart
    app_version              = module.argocd.argocd.release_metadata[0].app_version
    namespace                = module.argocd.argocd.release_metadata[0].namespace
    url                      = "https://${local.hostname}"
    documentation            = <<EOF
# ArgoCD Credentials
```bash
aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.argocd.name} --region ${var.dependency.cloud_provider.region} | jq .SecretString
```
EOF
  }
}