#!/usr/bin/env bash
# Copies the newest Azure actual cost file for last month and this month into
# the landing bucket, then loads each month into its own partition of
# cost_raw.azure_actual.
#
# Azure writes a new file into the month's folder every evening, and each one
# holds the whole month so far. Only the newest file in a folder is loaded,
# and it replaces the partition. Loading every file, or appending, would count
# the early days of the month once for every file.
#
# Every column is loaded as text. The file has 61 columns, dates written as
# MM/DD/YYYY and tags as JSON in a single column, and letting BigQuery guess
# the types each night risks a different guess and a failed load. The views
# in the reporting layer do the typing.
#
# Expects to be signed in to Azure and GCP already, which the workflow does.
set -euo pipefail

: "${EXPORT_ACCOUNT:?}" "${EXPORT_CONTAINER:?}" "${EXPORT_PREFIX:?}" "${LANDING_BUCKET:?}" "${GCP_PROJECT:?}" "${RAW_DATASET:?}"

this_month=$(date -u +%Y-%m)
last_month=$(date -u -d "$(date -u +%Y-%m-01) -1 month" +%Y-%m)

for period in "$last_month" "$this_month"; do
  # Month folders are named like 20260901-20260930.
  folder="${EXPORT_PREFIX}/${period/-/}01-"
  dest="gs://${LANDING_BUCKET}/azure/billing_period=${period}"
  partition="${period/-/}"

  newest=$(az storage blob list --account-name "$EXPORT_ACCOUNT" \
    --container-name "$EXPORT_CONTAINER" --prefix "$folder" --auth-mode login \
    --query "sort_by([], &properties.lastModified)[-1].name" -o tsv)

  if [ -z "$newest" ]; then
    echo "No Azure export for ${period}, skipping."
    continue
  fi
  echo "Newest Azure file for ${period}: ${newest}"

  workdir=$(mktemp -d)
  az storage blob download --account-name "$EXPORT_ACCOUNT" \
    --container-name "$EXPORT_CONTAINER" --name "$newest" --auth-mode login \
    --file "$workdir/actualcost.csv" -o none --no-progress

  # Build an all-text schema from the header row, dropping the byte order
  # mark Azure puts at the start of the file.
  schema=$(head -n 1 "$workdir/actualcost.csv" | sed 's/^\xEF\xBB\xBF//' | tr -d '\r' \
    | tr ',' '\n' | sed 's/$/:STRING/' | paste -sd, -)

  if gcloud storage ls "${dest}/" > /dev/null 2>&1; then
    gcloud storage rm "${dest}/**" --quiet
  fi
  gcloud storage cp "$workdir/actualcost.csv" "${dest}/actualcost.csv"

  bq --project_id="$GCP_PROJECT" --location=EU load \
    --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines \
    --replace --time_partitioning_type=MONTH \
    "${RAW_DATASET}.azure_actual\$${partition}" "${dest}/actualcost.csv" "$schema"

  echo "Loaded Azure ${period}:"
  bq --project_id="$GCP_PROJECT" --location=EU query --use_legacy_sql=false --format=pretty \
    "SELECT COUNT(*) AS row_count,
            ROUND(SUM(CAST(costInBillingCurrency AS FLOAT64)), 4) AS billed_cost
     FROM \`${GCP_PROJECT}.${RAW_DATASET}.azure_actual\`
     WHERE _PARTITIONTIME = TIMESTAMP('${period}-01')"

  rm -rf "$workdir"
done
