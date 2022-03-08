
variable "dependency" {
  type = object({
    cloud_provider = object({
      type = string
      region = string
      projectId = string
    })
    cloudfairy_connector_extract_database_env_vars = any
    vpc = any
  })
}

variable "config" {
  type = any
}

locals {
  db_envs = try(var.dependency.cloudfairy_connector_extract_database_env_vars, [])
}

output "cfout" {
  value = {
    public_url = google_cloud_run_service.web_service.url
  }
}

resource "google_cloud_run_service" "web_service" {
  name     = var.config.serviceName
  location = var.dependency.cloud_provider.region
  autogenerate_revision_name = true
  project = var.dependency.cloud_provider.projectId

  lifecycle {
    ignore_changes = [
      template[0].metadata[0].annotations["client.knative.dev/user-image"],
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
      template[0].metadata[0].annotations["run.googleapis.com/sandbox"],
      metadata[0].annotations["serving.knative.dev/creator"],
      metadata[0].annotations["serving.knative.dev/lastModifier"],
      metadata[0].annotations["run.googleapis.com/ingress-status"],
      metadata[0].labels["cloud.googleapis.com/location"],
    ]
  }

  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"

        dynamic "env" {
          for_each = local.db_envs
          content {
            name = env.value["name"]
            value = env.value["value"]
          }
        }
      }
    }

    metadata {
      annotations = {
        "run.googleapis.com/ingress" = var.config.public ? "all" : "private-ranges-only"
        
        # access via VPC
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
        "run.googleapis.com/vpc-access-egress" = "all"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_project_service" "vpcaccess-api" {
  project = var.dependency.cloud_provider.projectId
  service = "vpcaccess.googleapis.com"
}

# VPC access connector
resource "google_vpc_access_connector" "connector" {
  name          = "vpcconn-${var.config.serviceName}"
  region        = var.dependency.cloud_provider.region
  network       = var.dependency.vpc.vpcName
  depends_on    = [google_project_service.vpcaccess_api]
}

resource "google_cloud_run_service_iam_member" "public_access" {
  depends_on = [
    google_cloud_run_service.web_service
  ]
  count = var.public ? 1 : 0
  service = google_cloud_run_service.default.name
  location = google_cloud_run_service.default.location
  project = google_cloud_run_service.default.project
  role = "roles/run.invoker"
  member = "allUsers"
}

resource "google_container_registry" "web_service_docker_registry" {
  project  = var.dependency.cloud_provider.projectId
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  depends_on = [google_cloud_run_service.web_service]
  
  location    = google_cloud_run_service.web_service.location
  project     = google_cloud_run_service.web_service.project
  service     = google_cloud_run_service.web_service.name

  policy_data = data.google_iam_policy.noauth.policy_data
}