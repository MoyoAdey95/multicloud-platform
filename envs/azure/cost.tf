# The cost ingest workflow's Azure identity, read-only on the one container
# the actual cost export writes to. The export and its storage account were
# set up by hand in rg-cost-exports before this repo. The container's ID is
# built from its parts rather than read with a data source, because the
# storage account data source also fetches the account keys into state.
locals {
  azure_export_container_id = join("/", [
    "/subscriptions/${var.azure_subscription_id}",
    "resourceGroups/${var.azure_export_resource_group}",
    "providers/Microsoft.Storage/storageAccounts/${var.azure_export_storage_account}",
    "blobServices/default/containers/${var.azure_export_container}",
  ])
}

module "github_cost_ingest_azure" {
  source = "../../modules/github-oidc-azure"

  identity_name       = "id-github-cost-ingest"
  resource_group_name = module.workload.resource_group
  location            = module.workload.location
  credential_name     = "github-main"
  github_subject      = local.github_subject
  tags                = local.common_tags

  role_assignments = {
    export-read = {
      scope = local.azure_export_container_id
      role  = "Storage Blob Data Reader"
    }
  }
}
