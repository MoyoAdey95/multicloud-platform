# The identity the plan and drift workflows use in GCP. It can read every
# resource the hub and gcp roots manage, and the state of all four roots, and
# change nothing. Plans run with -lock=false, so it never writes the lock
# file either.
#
# The roles are narrow predefined viewers rather than roles/viewer, which is
# a basic role and fails this repo's own policy.
resource "google_service_account" "plan" {
  account_id   = "github-plan"
  display_name = "GitHub plan and drift, read only"
}

# Trusted by runs on main, for the nightly drift check, and by pull requests.
resource "google_service_account_iam_member" "plan_wif" {
  for_each = toset([local.github_subject, local.github_pr_subject])

  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${module.github_oidc_gcp.pool_name}/subject/${each.value}"
}

resource "google_project_iam_member" "plan" {
  for_each = toset([
    "roles/iam.securityReviewer",
    "roles/iam.serviceAccountViewer",
    "roles/iam.workloadIdentityPoolViewer",
    "roles/serviceusage.serviceUsageViewer",
    "roles/run.viewer",
    "roles/artifactregistry.reader",
    "roles/bigquery.metadataViewer",
    "roles/monitoring.viewer",
    "roles/storage.bucketViewer",
  ])

  project = var.gcp_project
  role    = each.value
  member  = "serviceAccount:${google_service_account.plan.email}"
}

# The state bucket was made by hand before any root existed, so it is named
# here rather than managed. Object viewer reads state and cannot change it.
resource "google_storage_bucket_iam_member" "plan_state" {
  bucket = "moyo-platform-tfstate"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.plan.email}"
}
