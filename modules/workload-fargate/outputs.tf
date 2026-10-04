output "registry" {
  description = "ECR repository URL to push images to."
  value       = aws_ecr_repository.this.repository_url
}

output "service_url" {
  description = "Public URL of the load balancer in front of the service."
  value       = "http://${aws_lb.this.dns_name}"
}

output "task_role_arn" {
  description = "Role the task runs as. The hub trusts this role for telemetry."
  value       = aws_iam_role.task.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "Name of the ECS service, empty until it exists."
  value       = one(aws_ecs_service.this[*].name)
}
