# Full resource name of the provider, which is what google-github-actions/auth
# expects as workload_identity_provider.
output "provider_name" {
  description = "Resource name of the workload identity provider."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Email of the service account the workflow impersonates."
  value       = google_service_account.this.email
}

output "service_account_member" {
  description = "IAM member string for granting the service account roles."
  value       = "serviceAccount:${google_service_account.this.email}"
}

# Other service accounts in the same project can trust the same pool, so its
# name is exposed for their workloadIdentityUser bindings.
output "pool_name" {
  description = "Resource name of the workload identity pool."
  value       = google_iam_workload_identity_pool.this.name
}
