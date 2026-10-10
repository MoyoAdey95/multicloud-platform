#!/usr/bin/env bash
# Writes the number of requests each estate served per UTC day into
# cost_raw.requests_daily, so cost per request divides by what was actually
# served rather than by what the load workflow meant to send. Scheduled runs
# start late or not at all, so the two are not the same.
#
# The count comes from Managed Prometheus in the hub, as the increase in the
# app's request counter over each day, leaving out paths the app does not
# serve. Every day from START_DATE to yesterday is recomputed on each run and
# the table is replaced, which keeps a late sample from leaving a day short.
#
# Expects to be signed in to GCP already, which the workflow does.
set -euo pipefail

: "${GCP_PROJECT:?}" "${RAW_DATASET:?}" "${START_DATE:?}"

query_url="https://monitoring.googleapis.com/v1/projects/${GCP_PROJECT}/location/global/prometheus/api/v1/query"
token=$(gcloud auth print-access-token)
out=$(mktemp)

day="$START_DATE"
today=$(date -u +%Y-%m-%d)
while [ "$day" \< "$today" ]; do
  next=$(date -u -d "$day +1 day" +%Y-%m-%d)

  # Evaluated at midnight at the end of the day, over the 24 hours before it.
  curl -sf -H "Authorization: Bearer $token" "$query_url" \
    --data-urlencode 'query=sum by (cloud) (increase(app_requests_total{route!="unmatched"}[1d]))' \
    --data-urlencode "time=${next}T00:00:00Z" \
    | jq -c --arg day "$day" '.data.result[] | {day: $day, cloud: .metric.cloud, requests: (.value[1] | tonumber)}' \
    >> "$out"

  day="$next"
done

bq --project_id="$GCP_PROJECT" --location=EU load \
  --source_format=NEWLINE_DELIMITED_JSON --replace \
  "${RAW_DATASET}.requests_daily" "$out" day:DATE,cloud:STRING,requests:FLOAT

echo "Requests served per day:"
bq --project_id="$GCP_PROJECT" --location=EU query --use_legacy_sql=false --format=pretty \
  "SELECT day, cloud, ROUND(requests) AS requests
   FROM \`${GCP_PROJECT}.${RAW_DATASET}.requests_daily\`
   ORDER BY day, cloud"

rm -f "$out"
