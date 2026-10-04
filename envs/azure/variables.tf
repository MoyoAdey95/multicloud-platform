# A subscription ID identifies the subscription but grants nothing on its own.
variable "azure_subscription_id" {
  description = "Azure subscription for the Azure estate."
  type        = string
  default     = "fb41774d-87cb-41eb-997c-9dbe498cf34e"
}

variable "azure_location" {
  description = "Azure region for the Azure estate."
  type        = string
  default     = "uksouth"
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

# Empty on the first apply, which created the resource group, registry,
# identity and environment. The image was then pushed to the registry and
# its digest set here so the second apply could create the app. The digest
# is the same one Artifact Registry and ECR report.
variable "image" {
  description = "Image the container app runs, as registry/repository@sha256:digest."
  type        = string
  default     = "moyoplatformacr.azurecr.io/platform-api@sha256:3d2aae67d32b3f5db9cf883835567db7f9f36e298dd0044bdcdc05149792d948"
}
