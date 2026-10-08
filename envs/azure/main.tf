module "workload" {
  source = "../../modules/workload-containerapps"

  name          = "platform-api"
  location      = var.azure_location
  registry_name = "moyoplatformacr"
  image         = var.image

  collector_image = var.collector_image
  tags            = local.common_tags
}

# The deploy identity lives in the estate's resource group, so deleting the
# group removes it too.
module "github_oidc_azure" {
  source = "../../modules/github-oidc-azure"

  identity_name       = "id-github-deploy-azure"
  resource_group_name = module.workload.resource_group
  location            = module.workload.location
  credential_name     = "github-main"
  github_subject      = local.github_subject
  tags                = local.common_tags

  # Push to the one registry and update the one app. Nothing at resource
  # group or subscription level.
  role_assignments = {
    acr-push = {
      scope = module.workload.registry_id
      role  = "AcrPush"
    }
    app-deploy = {
      scope = module.workload.app_id
      role  = "Container Apps Contributor"
    }
  }
}

data "azurerm_client_config" "current" {}
