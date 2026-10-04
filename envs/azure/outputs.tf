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
