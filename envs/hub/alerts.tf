# Two alerts, each evaluated per cloud. A PromQL condition opens one incident
# per series it returns, and both queries group by cloud, so an error spike on
# Azure opens an Azure incident and leaves the other two estates alone.
#
# Both queries share the dashboard's filters. Scanner traffic (route
# "unmatched") is left out, and both need at least 15 real requests in the
# five-minute window before they can fire, so a single failed request on a
# quiet estate is not an incident.
#
# There is deliberately no alert on missing data. Cloud Run and Container Apps
# scale to zero between load runs, so on those estates no data is the normal
# state, and an absent-metrics alert would fire every hour.

locals {
  # Requests per second over five minutes that the app actually serves.
  served_rate = "sum by (cloud) (rate(app_requests_total{route!=\"unmatched\"}[5m]))"

  # 15 requests in five minutes.
  min_rate = 0.05
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "platform-api alerts"
  type         = "email"
  labels       = { email_address = var.alert_email }
  user_labels  = local.common_tags
}

resource "google_monitoring_alert_policy" "error_ratio" {
  display_name = "platform-api error ratio by cloud"
  combiner     = "OR"
  severity     = "ERROR"

  conditions {
    display_name = "5xx share of requests above ${var.error_ratio_threshold}"

    condition_prometheus_query_language {
      query               = "(sum by (cloud) (rate(app_requests_total{route!=\"unmatched\", status=~\"5..\"}[5m])) / ${local.served_rate}) > ${var.error_ratio_threshold} and ${local.served_rate} > ${local.min_rate}"
      duration            = "60s"
      evaluation_interval = "60s"
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    mime_type = "text/markdown"
    subject   = "platform-api errors high on $${metric.label.cloud}"
    content   = <<-EOT
      More than ${var.error_ratio_threshold * 100}% of requests on one estate returned 5xx over the last five minutes.

      Start with the dashboard, filtered to the cloud in this incident, then the app error logs panel under it. The hourly load run only calls `/`, so errors there point at the app or the platform, while errors on `/flaky` are expected from a firing test.
    EOT
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  user_labels           = local.common_tags
}

resource "google_monitoring_alert_policy" "latency" {
  display_name = "platform-api p95 latency by cloud"
  combiner     = "OR"
  severity     = "WARNING"

  conditions {
    display_name = "p95 above ${var.latency_threshold_seconds}s"

    condition_prometheus_query_language {
      query               = "histogram_quantile(0.95, sum by (cloud, le) (rate(app_request_duration_seconds_bucket{route!=\"unmatched\"}[5m]))) > ${var.latency_threshold_seconds} and ${local.served_rate} > ${local.min_rate}"
      duration            = "60s"
      evaluation_interval = "60s"
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    mime_type = "text/markdown"
    subject   = "platform-api slow on $${metric.label.cloud}"
    content   = <<-EOT
      p95 server-side latency on one estate was above ${var.latency_threshold_seconds}s over the last five minutes.

      This is time inside the app, measured by its own histogram, so it does not include cold starts or the load balancer. Check the dashboard's latency and request rate panels for the cloud in this incident.
    EOT
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  user_labels           = local.common_tags
}
