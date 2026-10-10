# The cost ingest workflow gets its own service account, separate from the
# deploy one, so neither can do the other's job. It trusts the same GitHub
# pool, narrowed to the same main-branch subject.
resource "google_service_account" "cost_ingest" {
  account_id   = "github-cost-ingest"
  display_name = "GitHub cost ingest"
}

resource "google_service_account_iam_member" "cost_ingest_wif" {
  service_account_id = google_service_account.cost_ingest.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${module.github_oidc_gcp.pool_name}/subject/${local.github_subject}"
}

resource "google_project_service" "bigquery" {
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

module "cost" {
  source = "../../modules/cost"

  project_id          = var.gcp_project
  location            = "EU"
  landing_bucket_name = "moyo-platform-cost-landing"
  ingest_member       = "serviceAccount:${google_service_account.cost_ingest.email}"
  gcp_focus_table     = var.gcp_focus_table
  gcp_detailed_table  = var.gcp_detailed_table
  create_views        = var.cost_views

  depends_on = [google_project_service.bigquery]
}

# The ingest job reads request counts from Managed Prometheus. Viewer reads
# metrics and dashboards and changes nothing.
resource "google_project_iam_member" "cost_ingest_monitoring" {
  project = var.gcp_project
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.cost_ingest.email}"
}
