# The cost pipeline from multicloud-cost-reporting, trimmed to what this repo
# needs. The AWS and Azure exports are copied into a landing bucket and loaded
# into a raw dataset by the ingest workflow. Views put all three providers on
# the same FOCUS columns. The GCP billing export is read where it already is,
# in another project, so nothing about it is copied.
#
# Terraform owns the bucket, the datasets, the grants and the views. The raw
# tables are created by the first load and replaced a month at a time after
# that, so their data belongs to the pipeline.

# BigQuery only loads from a bucket in the same location as the dataset, and
# the GCP billing export is in the EU multi-region, so everything here is too.
resource "google_storage_bucket" "landing" {
  project                     = var.project_id
  name                        = var.landing_bucket_name
  location                    = var.location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  # The files are copies of exports that still exist at the source.
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_bigquery_dataset" "raw" {
  project                    = var.project_id
  dataset_id                 = "cost_raw"
  location                   = var.location
  description                = "AWS and Azure cost exports as loaded, before any mapping."
  delete_contents_on_destroy = true
}

resource "google_bigquery_dataset" "reporting" {
  project                    = var.project_id
  dataset_id                 = "cost_reporting"
  location                   = var.location
  description                = "AWS, GCP and Azure cost on shared FOCUS columns, and the platform's unit cost."
  delete_contents_on_destroy = true
}

# The ingest identity writes to the landing bucket and the raw dataset, and
# can run jobs. It cannot read or change the reporting views.
resource "google_storage_bucket_iam_member" "ingest_landing" {
  bucket = google_storage_bucket.landing.name
  role   = "roles/storage.objectAdmin"
  member = var.ingest_member
}

resource "google_bigquery_dataset_iam_member" "ingest_raw" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.raw.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = var.ingest_member
}

resource "google_project_iam_member" "ingest_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = var.ingest_member
}

locals {
  raw_dataset       = "${var.project_id}.${google_bigquery_dataset.raw.dataset_id}"
  reporting_dataset = "${var.project_id}.${google_bigquery_dataset.reporting.dataset_id}"

  provider_views = {
    focus_aws   = templatefile("${path.module}/sql/focus_aws.sql", { raw_dataset = local.raw_dataset })
    focus_gcp   = templatefile("${path.module}/sql/focus_gcp.sql", { gcp_focus_table = var.gcp_focus_table })
    focus_azure = templatefile("${path.module}/sql/focus_azure.sql", { raw_dataset = local.raw_dataset })
  }
}

# The AWS and Azure views read raw tables that only exist after the first
# load. On a new build the first apply sets create_views to false, the ingest
# workflow runs once, and the next apply creates the views.
resource "google_bigquery_table" "focus" {
  for_each = var.create_views ? local.provider_views : {}

  project             = var.project_id
  dataset_id          = google_bigquery_dataset.reporting.dataset_id
  table_id            = each.key
  deletion_protection = false

  view {
    query          = each.value
    use_legacy_sql = false
  }
}

resource "google_bigquery_table" "focus_all" {
  count = var.create_views ? 1 : 0

  project             = var.project_id
  dataset_id          = google_bigquery_dataset.reporting.dataset_id
  table_id            = "focus_all"
  deletion_protection = false

  view {
    query          = templatefile("${path.module}/sql/focus_all.sql", { dataset = local.reporting_dataset })
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.focus]
}

# The pipeline's total per provider and month next to a total from a separate
# source. Every number built on these views is only as good as this check.
resource "google_bigquery_table" "reconciliation" {
  count = var.create_views ? 1 : 0

  project             = var.project_id
  dataset_id          = google_bigquery_dataset.reporting.dataset_id
  table_id            = "reconciliation"
  deletion_protection = false

  view {
    query = templatefile("${path.module}/sql/reconciliation.sql", {
      dataset            = local.reporting_dataset
      raw_dataset        = local.raw_dataset
      gcp_detailed_table = var.gcp_detailed_table
    })
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.focus_all]
}
