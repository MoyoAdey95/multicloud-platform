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
