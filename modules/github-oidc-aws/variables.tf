variable "role_name" {
  description = "Name of the IAM role the workflow assumes."
  type        = string
}

variable "role_description" {
  description = "Description of the IAM role."
  type        = string
}

variable "github_subject" {
  description = "Full sub claim the workflow's token carries, including the ref."
  type        = string
}

variable "policy_json" {
  description = "Inline policy document with everything the role is allowed to do."
  type        = string
}
