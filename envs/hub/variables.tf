variable "gcp_project" {
  description = "GCP project that holds the hub and the GCP estate."
  type        = string
  default     = "multicloud-platform-lab"
}

variable "gcp_region" {
  description = "Default GCP region for regional resources."
  type        = string
  default     = "europe-west2"
}

variable "project" {
  description = "Project tag or label applied to every resource."
  type        = string
  default     = "multicloud-platform"
}

variable "env" {
  description = "Environment tag or label applied to every resource."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag or label applied to every resource."
  type        = string
  default     = "moyo"
}

variable "github_owner_id" {
  description = "Numeric ID of the GitHub account that owns this repository."
  type        = string
  default     = "212127446"
}

variable "github_repository_id" {
  description = "Numeric ID of this repository on GitHub."
  type        = string
  default     = "1404214134"
}

# Read from GitHub with
# gh api repos/MoyoAdey95/multicloud-platform/actions/oidc/customization/sub
# rather than typed by hand. The repo uses the immutable form, with the owner
# and repository IDs next to their names, so a renamed or recreated repo with
# the same name is not trusted.
variable "github_sub_prefix" {
  description = "Start of the OIDC sub claim GitHub issues for this repository."
  type        = string
  default     = "repo:MoyoAdey95@212127446/multicloud-platform@1404214134"
}

# Kept out of the repo. Set in envs/hub/terraform.tfvars, which git ignores.
variable "alert_email" {
  description = "Address the alert policies notify."
  type        = string
}

variable "error_ratio_threshold" {
  description = "Share of requests returning 5xx, per cloud, above which the error alert fires."
  type        = number
  default     = 0.1
}

variable "latency_threshold_seconds" {
  description = "p95 server-side latency, per cloud, above which the latency alert fires."
  type        = number
  default     = 1
}
