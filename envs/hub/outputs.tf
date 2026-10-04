output "github_workload_identity_provider" {
  description = "Provider resource name for google-github-actions/auth."
  value       = module.github_oidc_gcp.provider_name
}

output "github_deploy_service_account" {
  description = "Service account GitHub Actions deploys the GCP estate as."
  value       = module.github_oidc_gcp.service_account_email
}

output "github_pool_name" {
  description = "Resource name of the GitHub workload identity pool."
  value       = module.github_oidc_gcp.pool_name
}

output "estates_pool_name" {
  description = "Resource name of the pool the AWS and Azure estates sign in through."
  value       = module.estate_federation.pool_name
}

output "estates_aws_provider" {
  description = "Resource name of the AWS provider in the estates pool."
  value       = module.estate_federation.aws_provider_name
}

output "estates_aws_principal" {
  description = "Principal set the AWS task role becomes after the exchange."
  value       = module.estate_federation.aws_principal
}

output "estates_azure_provider" {
  description = "Resource name of the Azure provider in the estates pool."
  value       = module.estate_federation.azure_provider_name
}

output "estates_azure_principal" {
  description = "Principal the Azure managed identity becomes after the exchange."
  value       = module.estate_federation.azure_principal
}
