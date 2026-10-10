output "landing_bucket" {
  description = "Name of the landing bucket."
  value       = google_storage_bucket.landing.name
}

output "raw_dataset_id" {
  description = "ID of the raw dataset."
  value       = google_bigquery_dataset.raw.dataset_id
}

output "reporting_dataset_id" {
  description = "ID of the reporting dataset."
  value       = google_bigquery_dataset.reporting.dataset_id
}
