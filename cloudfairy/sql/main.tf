variable "config" {
  type = any
}

variable "dependency" {
  type = any
}

resource "random_string" "prefix" {
  length = 6
  special = false
  lower = true
  upper = false
  number = false
}

resource "random_string" "password" {
  length = 16
  lower = true
  upper = true
  number = true
  special = true
}

# Reserve global internal address range for the peering
resource "google_compute_global_address" "private_ip_address_for_sql" {
  name          = "${var.config.instanceName}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.dependency.vpc.vpcName
}

# Establish VPC network peering connection using the reserved address range
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.dependency.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address_for_sql.name]
}

resource "google_sql_database_instance" "db_instance" {
  depends_on = [google_service_networking_connection.private_vpc_connection, google_compute_global_address.private_ip_address_for_sql]
  name = "${random_string.prefix.result}-${var.config.instanceName}"
  database_version = var.config.sqlType
  region           = var.dependency.cloud_provider.region
  deletion_protection = false

  settings {
    tier = var.config.tier
    disk_autoresize = true

    ip_configuration {
      ipv4_enabled = false
      private_network = var.dependency.vpc.vpcId
      require_ssl = true
    }
  }
}

resource "google_sql_database" "database" {
  name = "${random_string.prefix.result}-${var.config.instanceName}"
  instance = google_sql_database_instance.db_instance.name
}

resource "google_sql_user" "admin_for_db_instance" {
  instance = google_sql_database_instance.db_instance.name
  name = "${random_string.prefix.result}-admin"
  password = random_string.password.result
  type = "BUILT_IN"
  deletion_policy = "ABANDON"
}

output "cfout" {
  value = {
    instanceName = google_sql_database_instance.db_instance.name
    connectionName = google_sql_database_instance.db_instance.connection_name
    databaseIPAddress = google_sql_database_instance.db_instance.ip_address.0.ip_address
    databaseIPAddressType = google_sql_database_instance.db_instance.ip_address.0.type
    databaseName = google_sql_database.database.name
    admin_username = google_sql_user.admin_for_db_instance.name
    admin_password = random_string.password.result
  }
}