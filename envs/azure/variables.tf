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

# Built by .github/workflows/collector-image.yml from commit 234c251. The
# digest is the same in all three registries.
variable "collector_image" {
  description = "Collector image the app runs next to it, by digest."
  type        = string
  default     = "moyoplatformacr.azurecr.io/platform-api@sha256:6e43a8415b9b8867195309e28b3977b528a99a4cb2be7bfed2ebde8978a8d8d1"
}
