output "registry" {
  description = "Login server of the registry to push images to."
  value       = azurerm_container_registry.this.login_server
}

output "service_url" {
  description = "Public URL of the container app, empty until it exists."
  value       = one([for a in azurerm_container_app.this : "https://${a.ingress[0].fqdn}"])
}

output "identity_client_id" {
  description = "Client ID of the managed identity the app runs as."
  value       = azurerm_user_assigned_identity.app.client_id
}

output "identity_principal_id" {
  description = "Object ID of the managed identity the app runs as."
  value       = azurerm_user_assigned_identity.app.principal_id
}

output "resource_group" {
  description = "Resource group that holds the whole estate."
  value       = azurerm_resource_group.this.name
}
