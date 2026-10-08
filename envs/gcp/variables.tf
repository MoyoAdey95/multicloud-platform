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

# Empty on the first apply, which created the registry alone. The image was
# then pushed to that registry, tagged with the commit that added the app,
# and its digest set here so the second apply could create the service.
variable "image" {
  description = "Image the Cloud Run service runs, as registry/path@sha256:digest."
  type        = string
  default     = "europe-west2-docker.pkg.dev/multicloud-platform-lab/platform-api/platform-api@sha256:3d2aae67d32b3f5db9cf883835567db7f9f36e298dd0044bdcdc05149792d948"
}

# Built by .github/workflows/collector-image.yml from commit 234c251 and
# pushed to all three registries with the same digest.
variable "collector_image" {
  description = "Collector image the service runs next to the app, by digest."
  type        = string
  default     = "europe-west2-docker.pkg.dev/multicloud-platform-lab/platform-api/platform-api@sha256:ed29faeafee8bd57a3b85492fd8595b6ab38a1d41aee8f78f6ea4df6c2710bc2"
}
