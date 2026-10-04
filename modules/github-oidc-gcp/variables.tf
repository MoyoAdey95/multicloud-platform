variable "project_id" {
  description = "Project the pool and service account are created in."
  type        = string
}

# Pool and provider IDs cannot be reused for 30 days after deletion, so pick
# them once.
variable "pool_id" {
  description = "ID of the workload identity pool."
  type        = string
}

variable "pool_display_name" {
  description = "Display name of the workload identity pool."
  type        = string
}

variable "provider_id" {
  description = "ID of the GitHub provider inside the pool."
  type        = string
}

variable "github_owner_id" {
  description = "Numeric ID of the GitHub account that owns the repository."
  type        = string
}

variable "github_repository_id" {
  description = "Numeric ID of the GitHub repository."
  type        = string
}

variable "github_subject" {
  description = "Full sub claim the workflow's token carries, including the ref."
  type        = string
}

variable "service_account_id" {
  description = "Account ID of the service account the workflow becomes."
  type        = string
}

variable "service_account_display_name" {
  description = "Display name of the service account."
  type        = string
}
