# Public website cloudfairy module

# dependencies:
# - cloudfairy/cloud-provider

variable "properties" {
  type = any
}
variable "dependency" {
  type = any
}

resource "google_storage_bucket" "storage" {
  count = var.dependency.cloud_provider.type == "gcp" ? 1 : 0
  name  = var.properties.bucketName
  # uniform_bucket_level_access = true
  project       = var.dependency.cloud_provider.projectId
  location      = var.dependency.cloud_provider.region
  storage_class = "REGIONAL"
  force_destroy = false

  website {
    main_page_suffix = var.properties.indexPage
    not_found_page   = var.properties.errorPage
  }

  cors {
    origin          = ["*"]
    method          = ["GET"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}


resource "google_storage_bucket_access_control" "storage_public_rule" {
  count  = var.dependency.cloud_provider.type == "gcp" ? 1 : 0
  bucket = google_storage_bucket.storage[0].name
  role   = "READER"
  entity = "allUsers"
}

output "url" {
  value = google_storage_bucket.storage[0].url
}

output "self_link" {
  value = google_storage_bucket.storage[0].self_link
}

output "instructions" {
  value = {
    "deployment" : "gsutil rsync -r %DIST_FOLDER% ${google_storage_bucket.storage[0].self_link}"
  }
}
