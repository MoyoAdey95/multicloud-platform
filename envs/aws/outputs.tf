output "registry" {
  description = "ECR repository URL to push images to."
  value       = module.workload.registry
}

output "service_url" {
  description = "Public URL of the AWS estate."
  value       = module.workload.service_url
}

output "task_role_arn" {
  description = "Role the ECS task runs as."
  value       = module.workload.task_role_arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.workload.cluster_name
}

output "service_name" {
  description = "Name of the ECS service."
  value       = module.workload.service_name
}
