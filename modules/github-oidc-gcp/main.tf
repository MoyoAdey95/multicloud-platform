# Lets one GitHub repository's workflows act as a GCP service account without
# a key. The service account's roles are granted by the caller, so the module
# knows nothing about what the workflow deploys.

resource "google_iam_workload_identity_pool" "this" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = var.pool_display_name
  description               = "Identities from GitHub Actions."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub Actions"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
  }

  # Any GitHub repository can ask for a token from the same issuer, so the
  # provider refuses everything except this one. Matching on numeric IDs means
  # a rename does not break it and a new repo reusing the name does not pass.
  attribute_condition = "assertion.repository_owner_id == '${var.github_owner_id}' && assertion.repository_id == '${var.github_repository_id}'"
}

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = var.service_account_display_name
}

# The provider lets any branch of the repo in. This binding narrows it to the
# exact subject, which includes the ref, so only runs on that branch can
# become the service account.
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.this.name}/subject/${var.github_subject}"
}
