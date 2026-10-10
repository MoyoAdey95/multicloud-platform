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
