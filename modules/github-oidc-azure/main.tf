# Lets one GitHub repository's workflows sign in to Azure as a managed
# identity, with no client secret. The role assignments come in from the
# caller, so another repo can copy the folder and use it as it is.

resource "azurerm_user_assigned_identity" "this" {
  name                = var.identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Azure has no separate provider or pool. The credential holds the issuer,
# audience and exact subject together, and a token has to match all three.
resource "azurerm_federated_identity_credential" "github" {
  name                      = var.credential_name
  user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = var.github_subject
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  principal_type       = "ServicePrincipal"
}
