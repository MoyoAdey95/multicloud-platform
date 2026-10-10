variable "project_id" {
  description = "Project the bucket and datasets are created in."
  type        = string
}

variable "location" {
  description = "Location of the bucket and datasets. Must match the GCP billing export."
  type        = string
}

variable "landing_bucket_name" {
  description = "Bucket the ingest workflow copies the AWS and Azure export files into."
  type        = string
}

variable "ingest_member" {
  description = "IAM member string of the identity that runs the ingest workflow."
  type        = string
}

variable "gcp_focus_table" {
  description = "GCP FOCUS billing export table, project.dataset.table."
  type        = string
}

variable "gcp_detailed_table" {
  description = "GCP detailed usage billing export table, used only to reconcile."
  type        = string
}

variable "create_views" {
  description = "Whether to create the views. False only for the first apply, before any raw table exists."
  type        = bool
  default     = true
}

variable "unit_cost_start_date" {
  description = "First day the unit cost view covers, the day all three estates were live with load."
  type        = string
  default     = "2026-10-05"
}

variable "platform_project_tag" {
  description = "Value of the project tag on this platform's resources."
  type        = string
  default     = "multicloud-platform"
}

variable "aws_estate_services" {
  description = "AWS services whose untagged charges are inferred to belong to the AWS estate."
  type        = list(string)
  default     = ["Amazon Elastic Container Service", "Amazon Virtual Private Cloud", "Elastic Load Balancing"]
}
