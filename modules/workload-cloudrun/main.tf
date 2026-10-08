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
# service account, which has Editor on the project. Its only roles are the
# metric and log writing the collector needs, granted in the hub.
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

    # Named so CI can update this container's image on its own, now that the
    # service runs two.
    containers {
      name  = "api"
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

      # The app sends its logs to the collector next to it. The OTLP exporter
      # adds /v1/logs to this itself.
      dynamic "env" {
        for_each = var.collector_image == "" ? [] : [1]
        content {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "http://127.0.0.1:4318"
        }
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

    # The collector runs next to the app in the same instance. It gets its
    # Google identity from the metadata server as the runtime service
    # account, so no credential file is used here.
    #
    # With request-based billing the instance only has CPU while a request is
    # being served, and that includes this container. Scrapes and exports
    # happen in bursts that follow the traffic rather than every 30 seconds.
    # Counters are cumulative, so totals still add up. Always-on CPU would
    # smooth it out, at the price of billing every idle minute an instance
    # stays up.
    dynamic "containers" {
      for_each = var.collector_image == "" ? [] : [var.collector_image]
      content {
        name  = "collector"
        image = containers.value

        resources {
          limits = {
            cpu    = "1"
            memory = "256Mi"
          }
          cpu_idle = true
        }

        env {
          name  = "CLOUD"
          value = "gcp"
        }
      }
    }
  }

  # CI owns the image after the first deploy and pushes a new digest per
  # commit, and gcloud records itself as the client that made the change.
  # Without this, every plan would roll the service back to var.image.
  # Terraform still owns everything else about the service.
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
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
