# The identity the plan and drift workflows use in Azure. Reader on the
# estate's resource group covers everything this root manages there,
# including the role assignments and federated credentials, and Reader on the
# export container covers the one assignment outside it. Reader is the only
# role this repo assigns to a whole resource group.
module "github_plan_azure" {
  source = "../../modules/github-oidc-azure"

  identity_name       = "id-github-plan"
  resource_group_name = module.workload.resource_group
  location            = module.workload.location
  credential_name     = "github-main"
  github_subject      = local.github_subject
  extra_subjects      = { github-pr = local.github_pr_subject }
  tags                = local.common_tags

  role_assignments = {
    estate-read = {
      scope = "/subscriptions/${var.azure_subscription_id}/resourceGroups/${module.workload.resource_group}"
      role  = "Reader"
    }
    export-read = {
      scope = local.azure_export_container_id
      role  = "Reader"
    }
  }
}
