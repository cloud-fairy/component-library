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
  ssh_repo_url              = format("git@%s", replace(regex("(?:https:\\/\\/)(([0-9A-Za-z_\\-(\\.)]+)\\/([0-9A-Za-z_\\-(\\.)]+))(?:.*)$", var.properties.repo)[0], "/", ":"))
  ssh_repo_url_postfix      = regex("(?:https:\\/\\/)(?:[0-9A-Za-z_\\-(\\.)]+)\\/(?:[0-9A-Za-z_\\-(\\.)]+)(.*)$", var.properties.repo)[0]
  ssh_repo_url_full         = "${local.ssh_repo_url}${local.ssh_repo_url_postfix}"
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
  count                     = var.properties.repo_type == "git" ? 1 : 0
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
  count                     = var.properties.repo_type == "chart" ? 1 : 0

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
      repo_url              = local.ssh_repo_url_full
      chart                 = var.properties.appname
      #target_revision       = "1.2.3"
      helm {
        release_name        = var.properties.appname
        parameter {
          name              = "image.tag"
          value             = "1.2.3"
        }
        parameter {
          name              = "someotherparameter"
          value             = "true"
        }
        value_files         = ["values-test.yml"]
        values              = yamlencode({
          someparameter     = {
            enabled         = true
            someArray       = ["foo", "bar"]
          }
        })
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