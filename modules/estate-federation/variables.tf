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

variable "azure_tenant_id" {
  description = "Entra tenant the Azure estate's identity belongs to."
  type        = string
}

variable "azure_identity_object_id" {
  description = "Object ID of the managed identity the container app runs as."
  type        = string
}

# Read from the aud claim of a real token. Entra puts the application ID
# here, not the api://AzureADTokenExchange URI the token was requested for.
variable "azure_token_audience" {
  description = "Audience Entra puts in managed identity tokens for AzureADTokenExchange."
  type        = string
  default     = "fb60f99c-7a34-4190-8149-302f77469936"
}
