output "pool_name" {
  description = "Resource name of the estates pool."
  value       = google_iam_workload_identity_pool.this.name
}

output "aws_provider_name" {
  description = "Resource name of the AWS provider, used in the credential config."
  value       = google_iam_workload_identity_pool_provider.aws.name
}

output "aws_principal" {
  description = "Principal set the AWS task role becomes after the exchange."
  value       = local.aws_principal
}
