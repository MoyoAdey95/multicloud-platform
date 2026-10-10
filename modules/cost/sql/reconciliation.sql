-- Puts the pipeline's total for each provider and month next to a total from
-- a separate source, and shows the difference. Every report built on these
-- views is only as good as this check, so it is a view and reruns every time
-- rather than being a query that was run once.
--
-- For AWS and Azure the source is the raw export as loaded, which proves the
-- views lose and double count nothing. For GCP the source is Google's other
-- export, the detailed usage table, where billed cost is cost plus credits.
-- Two separate exports from the same provider agreeing is a real check.
--
-- A FULL JOIN is used so that a month present on only one side shows up with
-- a NULL instead of disappearing.
WITH pipeline AS (
  SELECT
    ProviderName,
    DATE(BillingPeriodStart) AS billing_month,
    SUM(BilledCost) AS pipeline_billed
  FROM `${dataset}.focus_all`
  GROUP BY 1, 2
),

source_totals AS (
  SELECT
    'AWS' AS ProviderName,
    DATE(BillingPeriodStart) AS billing_month,
    CAST(SUM(BilledCost) AS NUMERIC) AS source_billed,
    'AWS FOCUS export as loaded' AS source_name
  FROM `${raw_dataset}.aws_focus`
  GROUP BY 1, 2

  UNION ALL

  SELECT
    'Microsoft',
    DATE_TRUNC(PARSE_DATE('%m/%d/%Y', `date`), MONTH),
    CAST(SUM(CAST(costInBillingCurrency AS FLOAT64)) AS NUMERIC),
    'Azure actual cost export as loaded'
  FROM `${raw_dataset}.azure_actual`
  GROUP BY 1, 2

  UNION ALL

  SELECT
    'Google Cloud',
    PARSE_DATE('%Y%m', invoice.month),
    CAST(SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) AS c), 0)) AS NUMERIC),
    'GCP detailed usage export, cost plus credits'
  FROM `${gcp_detailed_table}`
  GROUP BY 1, 2
)

SELECT
  ProviderName,
  billing_month,
  ROUND(pipeline_billed, 6) AS pipeline_billed,
  ROUND(source_billed, 6) AS source_billed,
  ROUND(pipeline_billed - source_billed, 6) AS difference,
  source_name
FROM pipeline
FULL JOIN source_totals USING (ProviderName, billing_month)
