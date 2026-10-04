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
