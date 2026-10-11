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

# Terraform's azurerm provider calls listSecrets every time it reads a
# Container App, even one with no secrets, and listSecrets is an action that
# Reader does not include. No built-in role grants it without also allowing
# changes, so this role holds that one action and is assigned on the one app.
# The cost is that the plan identity could read the app's secrets, which is
# part of why the app keeps none and pulls images with a managed identity.
resource "azurerm_role_definition" "plan_app_secrets" {
  name        = "platform-api plan, Container App secrets read"
  scope       = "/subscriptions/${var.azure_subscription_id}/resourceGroups/${module.workload.resource_group}"
  description = "Lets the read-only plan identity read a Container App the way the azurerm provider does."

  permissions {
    actions = ["Microsoft.App/containerApps/listSecrets/action"]
  }

  assignable_scopes = ["/subscriptions/${var.azure_subscription_id}/resourceGroups/${module.workload.resource_group}"]
}

resource "azurerm_role_assignment" "plan_app_secrets" {
  scope              = module.workload.app_id
  role_definition_id = azurerm_role_definition.plan_app_secrets.role_definition_resource_id
  principal_id       = module.github_plan_azure.principal_id
  principal_type     = "ServicePrincipal"
}
