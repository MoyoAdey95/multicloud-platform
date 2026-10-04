variable "identity_name" {
  description = "Name of the user-assigned managed identity."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the identity is created in."
  type        = string
}

variable "location" {
  description = "Azure region for the identity."
  type        = string
}

variable "credential_name" {
  description = "Name of the federated identity credential."
  type        = string
}

variable "github_subject" {
  description = "Full sub claim the workflow's token carries, including the ref."
  type        = string
}

variable "role_assignments" {
  description = "Roles to grant the identity, keyed by a short label."
  type = map(object({
    scope = string
    role  = string
  }))
}

variable "tags" {
  description = "Tags applied to the identity."
  type        = map(string)
}
