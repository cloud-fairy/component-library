terraform {
  required_providers {
    argocd                  = {
      source                = "oboukili/argocd"
      version               = "5.5.0"
    }
  }
}

provider "argocd" {
  server_addr               = "${local.hostname}:443"
  username                  = "admin"
  password                  = data.aws_secretsmanager_secret_version.argocd_admin.secret_string
}

locals {
  ssh_repo_url              = length(regexall("https://", var.properties.repo)) > 0 ? format("git@%s", replace(regex("(?:https:\\/\\/)(([0-9A-Za-z_\\-(\\.)]+)\\/([0-9A-Za-z_\\-(\\.)]+))(?:.*)$", var.properties.repo)[0], "/", ":")) : ""
  ssh_repo_url_postfix      = length(regexall("https://", var.properties.repo)) > 0  ? regex("(?:https:\\/\\/)(?:[0-9A-Za-z_\\-(\\.)]+)\\/(?:[0-9A-Za-z_\\-(\\.)]+)(.*)$", var.properties.repo)[0] : ""
  ssh_repo_url_full         = length(regexall("https://", var.properties.repo)) > 0  ? "${local.ssh_repo_url}${local.ssh_repo_url_postfix}" : var.properties.repo
  hostname                  = regex("(?:https:\\/\\/)(.*)", var.dependency.argocd.url)[0]
}

data "aws_secretsmanager_secret" "argocd_admin" {
  arn                       = var.dependency.argocd.admin_secret_arn
}

data "aws_secretsmanager_secret_version" "argocd_admin" {
  secret_id                 = data.aws_secretsmanager_secret.argocd_admin.id

  depends_on                = [ data.aws_secretsmanager_secret.argocd_admin ]
}

# Git Application
resource "argocd_application" "git" {
  count                     = var.properties.app_type == "git" ? 1 : 0
  metadata {
    name                    = var.properties.appname
    namespace               = "argocd"
    labels                  = {
      #test = "true"
    }
  }

  cascade                   = false # disable cascading deletion
  wait                      = false

  spec {
    project                 = "default"

    destination {
      server                = "https://kubernetes.default.svc"
      namespace             = var.properties.ns
    }

    source {
      repo_url              = local.ssh_repo_url_full
      path                  = var.properties.path
      target_revision       = var.properties.branch
    }
    sync_policy {
      automated {
        prune               = true
        self_heal           = true
        allow_empty         = true
      }

      retry {
        limit               = "5"
        backoff {
          duration          = "30s"
          max_duration      = "2m"
          factor            = "2"
        }
      }
    }
  }
}

# Helm application
resource "argocd_application" "helm" {
  count                     = var.properties.app_type == "chart" ? 1 : 0

  metadata {
    name                    = var.properties.appname
    namespace               = "argocd"
    labels                  = {
      #test                 = "true"
    }
  }

  spec {
    destination {
      server                = "https://kubernetes.default.svc"
      namespace             = var.properties.ns
    }

    source {
      repo_url              = var.properties.repo
      chart                 = var.properties.appname
      target_revision       = var.properties.branch
      
      helm {
        release_name        = var.properties.appname
      }
    }

    sync_policy {
      automated {
        prune               = true
        self_heal           = true
        allow_empty         = true
      }

      retry {
        limit               = "5"
        backoff {
          duration          = "30s"
          max_duration      = "2m"
          factor            = "2"
        }
      }
    }
  }
}

output "cfout" {
  value                     = {
    server_addr             = local.hostname
    appname                 = var.properties.appname
  }
}