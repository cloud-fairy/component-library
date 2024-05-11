/**

This is a no-op terraform for local cloudfairy environment.

*/

variable "properties" {
  type = any
}

variable "dependency" {
  type    = any
  default = {}
}

variable "project" {
  type = any
}

variable "connector" {
  type    = any
  default = []
}


locals {
  cluster = var.dependency.cloudfairy_cluster
  # gke_nodeport     = (var.properties.has_ingress == 1 || var.properties.has_ingress == "1") ? 80 : var.properties.container_port
  gke_nodeport     = var.properties.container_port
  env_name         = var.project.environment_name
  service_name     = var.properties.local_name
  docker_tag       = data.external.env.result["CI_COMMIT_SHA"] != "" ? data.external.env.result["CI_COMMIT_SHA"] : var.project.environment_name
  conn_to_chromadb = try(var.connector.cloudfairy_app_to_chromadb, [])
  conn_to_dockers  = try(var.connector.cloudfairy_service_to_dockerhub, [])
  conn_to_services = try(var.connector.cloudfairy_service_to_service, [])
  conn_to_pg_pods  = try(var.connector.cloudfairy_service_to_pod_in_cluster, [])
  conn_to_db_mongo = try(var.connector.cloudfairy_service_to_db_mongo, [])
  conn_to_storages = try(var.connector.cloudfairy_service_to_storage, [])
  conn_to_rds      = try(var.connector.cloudfairy_k8_microservice_to_managed_sql, [])
  raw_env_vars     = var.properties.env_vars != "" ? split(",", var.properties.env_vars) : []
  inject_env_vars_kv = flatten([
    for element in local.raw_env_vars : {
      name  = split("=", element)[0]
      value = split("=", element)[1]
    }
  ])
  inject_env_vars = flatten([local.conn_to_chromadb, local.conn_to_db_mongo, local.conn_to_pg_pods, local.conn_to_dockers, local.conn_to_services, local.conn_to_storages, local.conn_to_rds, local.inject_env_vars_kv])
}

data "google_client_config" "provider" {}

provider "kubernetes" {
  host  = "https://${local.cluster.hostname}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    local.cluster.cluster_ca_certificate
  )
}

data "external" "env" {
  program = ["bash", "${path.module}/env.bash"]
}

resource "kubernetes_deployment_v1" "app" {
  wait_for_rollout = false
  metadata {
    name      = local.service_name
    namespace = "default"
  }
  spec {
    replicas = var.properties.pod_count
    selector {
      match_labels = {
        "app" = local.service_name
      }
    }
    template {
      metadata {
        labels = {
          "app" = local.service_name
          "env" = local.env_name
        }
      }
      spec {
        service_account_name = "default"
        container {
          name = local.service_name
          # europe-north1-docker.pkg.dev/cloud-fairy-324304/stg-todoapp-repo/bff:stg
          image             = "${var.dependency.cloudfairy_cluster.container_registry_url}/${local.service_name}:${local.docker_tag}"
          image_pull_policy = "Always"
          dynamic "env" {
            for_each = flatten(local.inject_env_vars)
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
          port {
            container_port = var.properties.container_port
            protocol       = "TCP"
          }
          resources {
            limits = {
              "memory" = "1Gi"
              "cpu"    = "100m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = local.service_name
    namespace = "default"
    labels = {
      "app" = local.service_name
    }
    # annotations = {
    #   "cloud.google.com/neg" = "{\"ingress\": true,\"exposed_ports\":{\"${local.gke_nodeport}\":{}}}"
    # }
  }
  spec {
    # type = (var.properties.has_ingress == 1 || var.properties.has_ingress == "1") ? "ClusterIP" : "NodePort"
    type = "NodePort"
    port {
      port        = local.gke_nodeport
      target_port = var.properties.container_port
    }
    selector = {
      "app" = local.service_name
    }

    dynamic "port" {
      for_each = var.properties.debug_port == "-1" ? [] : [var.properties.debug_port]
      content {
        name        = "debug-port"
        port        = var.properties.debug_port
        target_port = var.properties.debug_port
      }
    }
  }
}

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}



provider "kubectl" {
  host                   = local.cluster.hostname
  cluster_ca_certificate = base64decode(local.cluster.cluster_ca_certificate)
  token                  = data.google_client_config.provider.access_token
  load_config_file       = false
}


resource "kubernetes_ingress_v1" "app" {
  count = var.properties.has_ingress
  metadata {
    name = local.service_name
    labels = {
      "app" = local.service_name
    }
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class" : "gce"
    }
  }
  spec {
    # ingress_class_name = "nginx"
    rule {
      http {
        path {
          path      = "/${local.service_name}"
          path_type = "Prefix"
          backend {
            service {
              name = local.service_name
              port {
                number = local.gke_nodeport
              }
            }
          }
        }
      }
    }
  }
}



output "cfout" {
  value = {
    pod_count    = var.properties.pod_count
    service_name = local.service_name
    hostname     = local.service_name
    port         = var.properties.container_port
  }
}
