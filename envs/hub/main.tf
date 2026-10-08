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

# The AWS root's state gives the task role, so its name is never typed here.
data "terraform_remote_state" "aws" {
  backend = "gcs"

  config = {
    bucket = "moyo-platform-tfstate"
    prefix = "multicloud-platform/aws"
  }
}

locals {
  aws_task_role_arn = data.terraform_remote_state.aws.outputs.task_role_arn
}

data "terraform_remote_state" "azure" {
  backend = "gcs"

  config = {
    bucket = "moyo-platform-tfstate"
    prefix = "multicloud-platform/azure"
  }
}

module "estate_federation" {
  source = "../../modules/estate-federation"

  project_id         = var.gcp_project
  pool_id            = "estates"
  aws_account_id     = split(":", local.aws_task_role_arn)[4]
  aws_task_role_name = element(split("/", local.aws_task_role_arn), length(split("/", local.aws_task_role_arn)) - 1)

  azure_tenant_id          = data.terraform_remote_state.azure.outputs.tenant_id
  azure_identity_object_id = data.terraform_remote_state.azure.outputs.identity_principal_id

  depends_on = [google_project_service.this]
}

# The GCP estate's collector runs as the Cloud Run runtime service account, so
# that account gets the same two write-only roles the AWS and Azure
# identities have. Granted here in the hub, next to theirs.
resource "google_project_iam_member" "gcp_telemetry" {
  for_each = toset(["roles/monitoring.metricWriter", "roles/logging.logWriter"])

  project = var.gcp_project
  role    = each.value
  member  = "serviceAccount:${local.gcp_estate.runtime_service_account}"
}
