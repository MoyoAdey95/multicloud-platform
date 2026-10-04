variable "project_id" {
  description = "Hub project the pool and the telemetry grants are in."
  type        = string
}

# Pool IDs are held for 30 days after deletion, so pick it once.
variable "pool_id" {
  description = "ID of the workload identity pool for the estates."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account the AWS estate runs in."
  type        = string
}

variable "aws_task_role_name" {
  description = "Name of the IAM role the ECS task runs as."
  type        = string
}

variable "telemetry_roles" {
  description = "Project roles the estates need to send metrics and logs."
  type        = list(string)
  default = [
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
  ]
}
