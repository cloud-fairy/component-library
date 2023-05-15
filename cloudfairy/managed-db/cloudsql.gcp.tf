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
  env_name        = var.project.environment_name
  project_name    = var.project.project_name
  region          = var.dependency.cloud_provider.region
  network         = var.dependency.network
  p_database_name = replace(var.properties.database_name, "_", "-")
  database_name   = "${local.p_database_name}-${local.env_name}"
  peering_name    = "${local.project_name}-${local.env_name}-${local.database_name}-peering"
}

# DB Network Peering

resource "google_compute_global_address" "peering_address" {
  provider      = google-beta
  name          = local.peering_name
  purpose       = "VPC_PEERING"
  ip_version    = "IPV4"
  address_type  = "INTERNAL"
  project       = var.dependency.cloud_provider.projectId
  prefix_length = 24
  network       = local.network.network_name
}

resource "google_service_networking_connection" "this" {
  depends_on = [
    google_compute_global_address.peering_address
  ]
  provider                = google-beta
  network                 = local.network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.peering_address.name]
}

# DB Instance
resource "google_sql_database_instance" "instance" {
  depends_on = [
    google_service_networking_connection.this
  ]

  database_version = var.properties.database_version
  name             = "${local.database_name}-instance"
  region           = local.region
  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    activation_policy = "ALWAYS"

    ip_configuration {
      ipv4_enabled    = true
      private_network = local.network.id
    }
  }
  deletion_protection = "false"
}

resource "google_sql_database" "this" {
  depends_on = [
    random_password.password,
    google_sql_user.user
  ]

  name     = local.database_name
  instance = google_sql_database_instance.instance.name
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*"
}

resource "google_sql_user" "user" {
  depends_on = [
    random_password.password
  ]
  name     = "${local.database_name}_user"
  instance = google_sql_database_instance.instance.name
  password = random_password.password.result
}

output "cfout" {
  sensitive = true
  value = {
    database = {
      name               = google_sql_database_instance.instance.name
      connection_name    = google_sql_database_instance.instance.connection_name
      private_ip_address = google_sql_database_instance.instance.private_ip_address
      ip_address         = google_sql_database_instance.instance.ip_address.0.ip_address
      public_ip_address  = google_sql_database_instance.instance.public_ip_address
      ca_cert            = google_sql_database_instance.instance.server_ca_cert.0.cert
      username           = google_sql_user.user.name
      password           = google_sql_user.user.password
    }
  }
}
