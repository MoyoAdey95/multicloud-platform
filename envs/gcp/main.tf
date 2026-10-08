# APIs this estate needs. Left enabled on destroy, because disabling an API
# can fail while anything else in the project still depends on it.
resource "google_project_service" "this" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

module "workload" {
  source = "../../modules/workload-cloudrun"

  name   = "platform-api"
  region = var.gcp_region
  image  = var.image

  collector_image = var.collector_image

  depends_on = [google_project_service.this]
}
