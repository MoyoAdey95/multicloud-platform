variable "aws_region" {
  description = "AWS region for the AWS estate."
  type        = string
  default     = "eu-west-2"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used when running Terraform by hand."
  type        = string
  default     = "personal"
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

# Empty on the first apply, which created the network, load balancer,
# registry and roles. The image was then pushed to the registry and its
# digest set here so the second apply could create the task definition and
# service. The digest is the same one Artifact Registry reports.
variable "image" {
  description = "Image the ECS service runs, as repository@sha256:digest."
  type        = string
  default     = "495599741450.dkr.ecr.eu-west-2.amazonaws.com/platform-api@sha256:3d2aae67d32b3f5db9cf883835567db7f9f36e298dd0044bdcdc05149792d948"
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
