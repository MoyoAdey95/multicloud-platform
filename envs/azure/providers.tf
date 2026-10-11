provider "azurerm" {
  subscription_id = var.azure_subscription_id

  # Storage data plane calls go through Entra ID rather than account keys.
  storage_use_azuread = true

  # The resource providers this root uses are registered already. Leaving
  # registration off means the read-only plan identity, which can only read
  # one resource group, can still start the provider.
  resource_provider_registrations = "none"

  features {}
}
