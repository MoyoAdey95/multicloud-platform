#!/usr/bin/env bash
# Makes the hub's alerts fire on all three clouds, to prove the path from a
# request on an estate to an email from the hub.
#
#   scripts/fire-alerts.sh errors    calls /flaky once a second for three
#                                    minutes on every estate. About 30% fail,
#                                    well over the 10% error-ratio threshold.
#
#   scripts/fire-alerts.sh latency   applies the hub with a 1 ms latency
#                                    threshold, runs the load workflow, waits
#                                    for the alerts, then puts the threshold
#                                    back and checks the hub matches the code.
#
# Expect one email per cloud a few minutes in, and a resolved notice on the
# same thread once the condition clears. Run from the repo root with the
# gcloud, gh and terraform logins the estates already use.
set -euo pipefail

HUB_QUERY="https://monitoring.googleapis.com/v1/projects/multicloud-platform-lab/location/global/prometheus/api/v1/query"

query() {
  curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" "$HUB_QUERY" \
    --data-urlencode "query=$1" | jq -r '.data.result[] | "  \(.metric.cloud) \(.value[1])"' | sort
}

case "${1:-}" in
  errors)
    date -u +"started %H:%M:%SZ"
    for e in gcp aws azure; do
      url=$(cd "envs/$e" && terraform output -raw service_url)
      (
        ok=0; err=0
        for _ in $(seq 1 180); do
          code=$(curl -s -o /dev/null -w "%{http_code}" "$url/flaky")
          if [ "$code" = "500" ]; then err=$((err + 1)); else ok=$((ok + 1)); fi
          sleep 1
        done
        echo "$e sent=180 ok=$ok err=$err"
      ) &
    done
    wait
    sleep 60
    echo "error ratio the alert sees:"
    query 'sum by (cloud) (rate(app_requests_total{route!="unmatched", status=~"5.."}[5m])) / sum by (cloud) (rate(app_requests_total{route!="unmatched"}[5m]))'
    ;;

  latency)
    (cd envs/hub && terraform apply -auto-approve -no-color -var latency_threshold_seconds=0.001 | grep -E "^Apply|Error")
    gh workflow run load.yml
    sleep 10
    run=$(gh run list --workflow load.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    gh run watch "$run" --exit-status > /dev/null
    date -u +"load finished %H:%M:%SZ"
    sleep 90
    echo "p95 the alert sees:"
    query 'histogram_quantile(0.95, sum by (cloud, le) (rate(app_request_duration_seconds_bucket{route!="unmatched"}[5m])))'
    # Leave the low threshold in place long enough for the incidents to open.
    sleep 330
    (cd envs/hub && terraform apply -auto-approve -no-color | grep -E "^Apply|Error")
    (cd envs/hub && terraform plan -no-color | grep -E "^Plan:|No changes|Error")
    ;;

  *)
    echo "usage: $0 errors|latency" >&2
    exit 1
    ;;
esac
