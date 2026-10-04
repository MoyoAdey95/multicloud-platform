provider "azurerm" {
  subscription_id = var.azure_subscription_id

  # Storage data plane calls go through Entra ID rather than account keys.
  storage_use_azuread = true

  features {}
}
