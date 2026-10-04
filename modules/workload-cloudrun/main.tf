resource "google_artifact_registry_repository" "this" {
  repository_id = var.name
  location      = var.region
  format        = "DOCKER"
  description   = "Images for the GCP estate."

  # Images are pushed with the git commit as the tag, so a tag never needs to
  # move. Immutable tags make sure it cannot.
  docker_config {
    immutable_tags = true
  }
}

# The service runs as its own identity rather than the default compute
# service account, which has Editor on the project. It has no roles yet.
# The collector added later is what needs permissions, and it gets only
# metric and log writing.
resource "google_service_account" "runtime" {
  account_id   = "${var.name}-run"
  display_name = "Runtime identity for the ${var.name} Cloud Run service"
}

# Nothing to run until an image has been pushed, so the service only exists
# once an image reference is passed in.
resource "google_cloud_run_v2_service" "this" {
  count = var.image == "" ? 0 : 1

  name                = var.name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.runtime.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        # Request-based billing. CPU is only charged while a request is
        # being handled, so an idle service costs nothing.
        cpu_idle = true
      }

      env {
        name  = "CLOUD"
        value = "gcp"
      }

      startup_probe {
        http_get {
          path = "/health"
        }
      }

      liveness_probe {
        http_get {
          path = "/health"
        }
      }
    }
  }
}

# Public, like the AWS and Azure estates, so one load generator can reach
# all three the same way.
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.image == "" ? 0 : 1

  name     = google_cloud_run_v2_service.this[0].name
  location = google_cloud_run_v2_service.this[0].location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
