#!/usr/bin/env bash
# Copies the AWS FOCUS export for last month and this month into the landing
# bucket, then loads each month into its own partition of cost_raw.aws_focus.
#
# AWS rewrites a month's Parquet file every day with the whole month so far,
# so each run replaces the partition rather than adding to it. Appending would
# count every day again on every run. Last month is included because late
# adjustments can still arrive for a few days after a month closes.
#
# Expects to be signed in to AWS and GCP already, which the workflow does.
set -euo pipefail

: "${EXPORT_BUCKET:?}" "${EXPORT_PREFIX:?}" "${LANDING_BUCKET:?}" "${GCP_PROJECT:?}" "${RAW_DATASET:?}"

this_month=$(date -u +%Y-%m)
last_month=$(date -u -d "$(date -u +%Y-%m-01) -1 month" +%Y-%m)

for period in "$last_month" "$this_month"; do
  src="s3://${EXPORT_BUCKET}/${EXPORT_PREFIX}/data/billing_period=${period}/"
  dest="gs://${LANDING_BUCKET}/aws/billing_period=${period}"
  partition="${period/-/}"

  if [ -z "$(aws s3 ls "$src" || true)" ]; then
    echo "No AWS export for ${period}, skipping."
    continue
  fi

  workdir=$(mktemp -d)
  aws s3 cp "$src" "$workdir/" --recursive --exclude "*" --include "*.parquet" --only-show-errors

  # Clear the month's old copy first, so a file AWS has dropped does not
  # linger and get loaded again.
  if gcloud storage ls "${dest}/" > /dev/null 2>&1; then
    gcloud storage rm "${dest}/**" --quiet
  fi
  gcloud storage cp "$workdir"/*.parquet "${dest}/"

  bq --project_id="$GCP_PROJECT" --location=EU load \
    --source_format=PARQUET --replace --time_partitioning_type=MONTH \
    "${RAW_DATASET}.aws_focus\$${partition}" "${dest}/*.parquet"

  echo "Loaded AWS ${period}:"
  bq --project_id="$GCP_PROJECT" --location=EU query --use_legacy_sql=false --format=pretty \
    "SELECT COUNT(*) AS row_count, ROUND(SUM(BilledCost), 4) AS billed_cost
     FROM \`${GCP_PROJECT}.${RAW_DATASET}.aws_focus\`
     WHERE _PARTITIONTIME = TIMESTAMP('${period}-01')"

  rm -rf "$workdir"
done
