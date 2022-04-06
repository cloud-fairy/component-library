variable "config" {
  type = any
}


variable "dependency" {
  type = any
}


resource "google_container_cluster" "cluster" {
  name = var.config.cluster_name
  location = var.dependency.cloud_provider.region
  network = var.dependency.vpc.vpcId
  subnetwork = var.dependency.vpc.subnetwork.name

  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    client_certificate_config {
      issue_client_certificate = true
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name = var.dependency.vpc.subnetwork.ip_range_pods
    services_secondary_range_name = var.dependency.vpc.subnetwork.ip_range_services
  }

  workload_identity_config {
    workload_pool = "${var.dependency.cloud_provider.projectId}.svc.id.goog"
  }
}

resource "google_container_registry" "registry" {
  project  = var.dependency.cloud_provider.projectId
}

resource "google_container_node_pool" "pool" {
  depends_on = [
    google_container_cluster.cluster
  ]
  
  name = "${var.config.cluster_name}-pool"
  location = var.dependency.cloud_provider.region
  cluster = google_container_cluster.cluster.name
  node_count = var.config.node_count

  node_config {
    preemptible = true
    machine_type = var.config.tier
    disk_size_gb = var.config.disk_size
    metadata ={
      disable-legacy-endpoints = "true"
    }
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

output "cfout" {
  value = {
    container = {
      id          = google_container_cluster.cluster.id
      self_link   = google_container_cluster.cluster.self_link
      endpoint    = google_container_cluster.cluster.endpoint
      host        = "https://${google_container_cluster.cluster.endpoint}"
      client_cert = google_container_cluster.cluster.master_auth.0.client_certificate
      client_key  = nonsensitive(google_container_cluster.cluster.master_auth.0.client_key)
      ca_cert     = google_container_cluster.cluster.master_auth.0.cluster_ca_certificate
    }
  }
}