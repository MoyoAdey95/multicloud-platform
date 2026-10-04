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
