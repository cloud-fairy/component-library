variable config {
  type = any
}

variable "dependency" {
  type = any
}

resource "google_compute_network" "vpc" {
  name = var.config.vpcName
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  name = "project-subnetwork"
  ip_cidr_range = "10.0.0.0/16"
  region = var.dependency.cloud_provider.region
  network = google_compute_network.vpc.self_link

  secondary_ip_range {
    range_name = "pods-cidr"
    ip_cidr_range = "10.3.0.0/16"
  }
  
  secondary_ip_range {
    range_name = "services-cidr"
    ip_cidr_range = "10.3.0.0/16"
  }
}

output "cfout" {
  value = {
    self_link = google_compute_network.vpc.self_link
    vpcId = google_compute_network.vpc.id
    vpcName = google_compute_network.vpc.name
    subnetwork = {
      name = google_compute_subnetwork.subnetwork.self_link
      ip_range_pods = google_compute_subnetwork.subnetwork.secondary_ip_range[0]
      ip_range_services = google_compute_subnetwork.subnetwork.secondary_ip_range[1]
    }
  }
}
