variable "properties" {
  type = object({
    node_count = number
    port       = number
    api_port   = number
  })
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

provider "external" {}
locals {
  cluster_name  = "${var.project.project_name}-localcluster"
  network_name  = "${var.project.project_name}-network"
  registry_name = "${var.project.project_name}-registry"
  api_port      = var.properties.api_port
  port          = var.properties.port
}


resource "k3d_registry" "registry" {
  name = local.registry_name
  #   network = local.network_name
  port {
    host      = local.registry_name
    host_port = 5001
  }
}

resource "k3d_cluster" "mycluster" {
  depends_on = [k3d_registry.registry]
  name       = local.cluster_name
  servers    = var.properties.node_count
  agents     = 1

  kube_api {
    host      = "localhost"
    host_ip   = "127.0.0.1"
    host_port = local.api_port
  }

  volume {
    source      = "${data.external.env.result["PWD"]}../../../../../../../../"
    destination = "/mnt/cloudfairy/root"
  }

  network = local.network_name

  registries {
    use = [local.registry_name]
    #     config = <<EOF
    # mirrors:
    #     "docker.io:
    #         endpoint:
    #         - "https://registry-1.docker.io"

    # EOF
  }

  port {
    host_port      = local.port
    container_port = 80
    node_filters = [
      "loadbalancer"
    ]
  }

  k3d {
    disable_load_balancer = false
    disable_image_volume  = false
  }

  kubeconfig {
    update_default_kubeconfig = true
    switch_current_context    = true
  }
}

resource "k3d_node" "mynode" {
  depends_on = [k3d_cluster.mycluster]
  name       = "${local.cluster_name}-node"

  cluster = local.cluster_name
  memory  = "512M"
  role    = "agent"
}

resource "time_sleep" "wait" {
  depends_on      = [k3d_cluster.mycluster, k3d_registry.registry, k3d_node.mynode]
  create_duration = "10s"
}

data "external" "env" {
  program = ["bash", "${path.module}/env.bash"]
}

provider "kubernetes" {
  host                   = k3d_cluster.mycluster.credentials.0.host
  client_certificate     = k3d_cluster.mycluster.credentials.0.client_certificate
  client_key             = k3d_cluster.mycluster.credentials.0.client_key
  cluster_ca_certificate = k3d_cluster.mycluster.credentials.0.cluster_ca_certificate
}

resource "kubernetes_service_account_v1" "serviceaccount" {
  depends_on = [time_sleep.wait]
  metadata {
    name      = "local-sa"
    namespace = "default"
  }
}

resource "kubernetes_persistent_volume_v1" "volume" {
  metadata {
    name = "root-volume"
    labels = {
      "type" = "local"
    }
  }
  spec {
    capacity = {
      "storage" = "30Gi"
    }
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteMany"]
    persistent_volume_source {
      host_path {
        path = "/mnt/cloudfairy/root"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "volume" {
  count            = 1
  wait_until_bound = false
  metadata {
    name = "root-volume-claim"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        "storage" = "2Gi"
      }
    }
    volume_name = "root-volume"
  }
}


output "cfout" {
  value = {
    hostname = "localhost"
    port     = local.port
    # host            = base64encode(k3d_cluster.mycluster.credentials.0.host)
    api_port        = local.api_port
    service_account = "local-sa"
    kubeconfig_path = "~/.kube/config"
    volume_path     = "/mnt/cloudfairy/root"
  }
}
