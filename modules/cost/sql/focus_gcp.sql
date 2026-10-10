-- GCP's FOCUS export is a preview and differs from the spec in two places
-- that matter here. It has no ServiceCategory, and its Tags column does not
-- hold labels. Labels are where project, env, owner and managed-by live on
-- GCP, and they come through as the extensions x_Labels for the resource and
-- x_ProjectLabels for its project. A resource's own label wins, and the
-- project's label fills in any key the resource does not set.
--
-- GCP's billing month runs on US Pacific time, so September starts at
-- 07:00 UTC. The other two start at midnight UTC. BillingPeriodStart is moved
-- to midnight on the same calendar date so the three group by month together.
SELECT
  ProviderName,
  BillingAccountId,
  SubAccountId,
  SubAccountName,
  TIMESTAMP(DATE(BillingPeriodStart, 'America/Los_Angeles')) AS BillingPeriodStart,
  ChargePeriodStart,
  ChargePeriodEnd,
  ChargeCategory,
  BillingCurrency,
  BilledCost,
  EffectiveCost,
  ListCost,
  ServiceName,
  CAST(NULL AS STRING) AS ServiceCategory,
  RegionId,
  ResourceId,
  ResourceName,
  ARRAY(
    SELECT AS STRUCT key, value
    FROM (
      SELECT l.Key AS key, l.Value AS value, 1 AS priority FROM UNNEST(x_Labels) AS l
      UNION ALL
      SELECT p.Key, p.Value, 2 FROM UNNEST(x_ProjectLabels) AS p
    )
    WHERE true
    QUALIFY ROW_NUMBER() OVER (PARTITION BY key ORDER BY priority) = 1
  ) AS Tags
FROM `${gcp_focus_table}`
