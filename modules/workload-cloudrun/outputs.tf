locals {
  repo = google_artifact_registry_repository.this
}

output "registry" {
  description = "Docker host and path to push images to."
  value       = "${var.region}-docker.pkg.dev/${local.repo.project}/${local.repo.repository_id}"
}

output "service_url" {
  description = "Public URL of the Cloud Run service, empty until it exists."
  value       = one(google_cloud_run_v2_service.this[*].uri)
}

output "runtime_service_account" {
  description = "Email of the identity the service runs as."
  value       = google_service_account.runtime.email
}
