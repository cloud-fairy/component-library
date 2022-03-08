variable config {
  type = any
}

resource "google_compute_network" "vpc" {
  name = var.config.vpcName
}

output "cfout" {
  value = {
    self_link = google_compute_network.vpc.self_link
    vpcId = google_compute_network.vpc.id
    vpcName = google_compute_network.vpc.name
  }
}
