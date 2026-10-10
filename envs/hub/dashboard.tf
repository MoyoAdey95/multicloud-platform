# One dashboard for all three estates. Every panel reads the same metrics from
# Managed Service for Prometheus and splits them by the cloud label the
# collectors add, so the estates line up on the same axes. The cloud variable
# at the top narrows every panel to one estate.
#
# The layout lives in a JSON file, the same shape the console exports, so a
# change made by hand in the console can be exported and diffed against it.
# The project ID is the only value filled in here. The file is read with
# file() and not templatefile(), so the dashboard's own ${cloud} references
# pass through untouched.
resource "google_monitoring_dashboard" "platform" {
  dashboard_json = replace(file("${path.module}/dashboards/platform.json"), "PROJECT_ID", var.gcp_project)
}
