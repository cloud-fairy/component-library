variable "properties" {
  # service_name
  # repo_url
  type = any
}

variable "project" {
  # environment_name
  type = any
}

variable "connector" {
  type    = any
  default = []
}


locals {
  bucket_region = substr(upper(var.project.CLOUD_REGION), 0, 2)
  project_name  = var.project.project_name
  env_name      = var.project.environment_name
}


resource "google_storage_bucket" "static_site" {
  name          = lower("${var.properties.bucketName}-${local.env_name}-${local.project_name}")
  project       = var.project.PROJECT_ID
  location      = local.bucket_region
  force_destroy = true
  storage_class = "STANDARD"

  website {
    main_page_suffix = var.properties.indexPage
    not_found_page   = var.properties.errorPage
  }
}

resource "google_storage_bucket_access_control" "public_rule" {
  bucket = google_storage_bucket.static_site.id
  role   = "READER"
  entity = "allUsers"
}



output "cfout" {
  value = {
    bucket_region = local.bucket_region
    hostname      = "Unknown"
    port          = 80
  }
}
