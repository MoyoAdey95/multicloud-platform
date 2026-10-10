output "registry" {
  description = "ACR login server to push images to."
  value       = module.workload.registry
}

output "service_url" {
  description = "Public URL of the Azure estate."
  value       = module.workload.service_url
}

output "identity_client_id" {
  description = "Client ID of the identity the app runs as."
  value       = module.workload.identity_client_id
}

output "identity_principal_id" {
  description = "Object ID of the identity the app runs as."
  value       = module.workload.identity_principal_id
}

output "resource_group" {
  description = "Resource group that holds the estate."
  value       = module.workload.resource_group
}

output "github_deploy_client_id" {
  description = "Client ID of the identity GitHub Actions deploys as."
  value       = module.github_oidc_azure.client_id
}

output "tenant_id" {
  description = "Entra tenant the subscription belongs to."
  value       = data.azurerm_client_config.current.tenant_id
}

output "github_cost_ingest_client_id" {
  description = "Client ID of the identity the cost ingest workflow signs in as."
  value       = module.github_cost_ingest_azure.client_id
}
