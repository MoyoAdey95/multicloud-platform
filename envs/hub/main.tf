# The hub and the GCP estate share a project, and a project has one GitHub
# pool, so the pool lives here. The identity APIs are turned on here too.
# iam.googleapis.com is already managed by the gcp root.
resource "google_project_service" "this" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

module "github_oidc_gcp" {
  source = "../../modules/github-oidc-gcp"

  project_id                   = var.gcp_project
  pool_id                      = "github"
  pool_display_name            = "GitHub"
  provider_id                  = "github-actions"
  github_owner_id              = var.github_owner_id
  github_repository_id         = var.github_repository_id
  github_subject               = local.github_subject
  service_account_id           = "github-deploy-gcp"
  service_account_display_name = "GitHub deploy to the GCP estate"

  depends_on = [google_project_service.this]
}

# The hub reads estate outputs, never the other way round. Here it needs the
# names of the three things the deploy identity is allowed to touch.
data "terraform_remote_state" "gcp" {
  backend = "gcs"

  config = {
    bucket = "moyo-platform-tfstate"
    prefix = "multicloud-platform/gcp"
  }
}

locals {
  gcp_estate = data.terraform_remote_state.gcp.outputs
}

# Push to the one repository.
resource "google_artifact_registry_repository_iam_member" "deploy_push" {
  location   = var.gcp_region
  repository = local.gcp_estate.repository_id
  role       = "roles/artifactregistry.writer"
  member     = module.github_oidc_gcp.service_account_member
}

# Deploy new revisions of the one service, without being able to change who
# can invoke it.
resource "google_cloud_run_v2_service_iam_member" "deploy_service" {
  location = var.gcp_region
  name     = local.gcp_estate.service_name
  role     = "roles/run.developer"
  member   = module.github_oidc_gcp.service_account_member
}

# A new revision runs as the runtime service account, and deploying it means
# acting as that account. Granted on that one account only.
resource "google_service_account_iam_member" "deploy_act_as_runtime" {
  service_account_id = "projects/${var.gcp_project}/serviceAccounts/${local.gcp_estate.runtime_service_account}"
  role               = "roles/iam.serviceAccountUser"
  member             = module.github_oidc_gcp.service_account_member
}
