output "registry" {
  description = "Docker host and path to push images to."
  value       = module.workload.registry
}

output "service_url" {
  description = "Public URL of the GCP estate."
  value       = module.workload.service_url
}

output "runtime_service_account" {
  description = "Identity the Cloud Run service runs as."
  value       = module.workload.runtime_service_account
}
