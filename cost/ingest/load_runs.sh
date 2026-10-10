#!/usr/bin/env bash
# Writes every load run's result per estate into cost_raw.load_runs, read
# from the load workflow's own logs. Each run prints one line per estate,
#   load cloud=aws sent=60 ok=60 first_s=... p50_s=... p95_s=... max_s=... at=...
# and that line is the record of what was sent and what succeeded.
#
# This is what cost per request divides by. Managed Prometheus has the same
# numbers from 10 October, but before then the AWS and Azure collectors were
# not running yet and cold starts on GCP were undercounted, so the hub's own
# counts cannot cover the whole billing window. requests.sh keeps loading them
# as a cross-check.
#
# Expects GH_TOKEN with read access to Actions, and to be signed in to GCP.
set -euo pipefail

: "${GITHUB_REPOSITORY:?}" "${GCP_PROJECT:?}" "${RAW_DATASET:?}" "${START_DATE:?}"

out=$(mktemp)

for run in $(gh run list --repo "$GITHUB_REPOSITORY" --workflow load.yml --status completed \
    --limit 500 --json databaseId,createdAt \
    --jq ".[] | select(.createdAt >= \"${START_DATE}\") | .databaseId"); do
  gh run view "$run" --repo "$GITHUB_REPOSITORY" --log \
    | grep -oE 'load cloud=[a-z]+ sent=[0-9]+ ok=[0-9]+ .* at=[0-9TZ:-]+' \
    | sed -E 's/.*cloud=([a-z]+) sent=([0-9]+) ok=([0-9]+) .* at=([0-9TZ:-]+)/\1 \2 \3 \4/' \
    | while read -r cloud sent ok at; do
        printf '{"run_id":%s,"cloud":"%s","sent":%s,"ok":%s,"at":"%s"}\n' "$run" "$cloud" "$sent" "$ok" "$at"
      done >> "$out"
done

bq --project_id="$GCP_PROJECT" --location=EU load \
  --source_format=NEWLINE_DELIMITED_JSON --replace \
  "${RAW_DATASET}.load_runs" "$out" run_id:INTEGER,cloud:STRING,sent:INTEGER,ok:INTEGER,at:TIMESTAMP

echo "Load requests that succeeded, per day:"
bq --project_id="$GCP_PROJECT" --location=EU query --use_legacy_sql=false --format=pretty \
  "SELECT DATE(at) AS day, cloud, COUNT(*) AS runs, SUM(ok) AS ok
   FROM \`${GCP_PROJECT}.${RAW_DATASET}.load_runs\`
   GROUP BY 1, 2 ORDER BY 1, 2"

rm -f "$out"
