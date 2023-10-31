variable "properties" {
  type = any
}

variable "dependency" {
  type = any
}

variable "project" {
  type = any
}

locals {
  cluster_name  = "${var.project.project_name}-localcluster"
  network_name  = "${var.project.project_name}-network"
  registry_name = "${var.project.project_name}-registry"
  port          = 6445
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
  name    = local.cluster_name
  servers = 1
  agents  = 1

  kube_api {
    host      = "localhost"
    host_ip   = "127.0.0.1"
    host_port = local.port
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
    host_port      = 8080
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


output "cfout" {
  value = {
    hostname        = "127.0.0.1"
    port            = local.port
    service_account = "local-sa"
  }
}
