-- AWS already exports FOCUS 1.2, so this is a trim to the shared columns.
-- Costs arrive as FLOAT and are cast to NUMERIC, which is what GCP uses and
-- what money should be. AWS prefixes user-defined tag keys with "user:" in
-- some exports, so the prefix is dropped to make the keys match the other two.
SELECT
  ProviderName,
  BillingAccountId,
  SubAccountId,
  SubAccountName,
  BillingPeriodStart,
  ChargePeriodStart,
  ChargePeriodEnd,
  ChargeCategory,
  BillingCurrency,
  CAST(BilledCost AS NUMERIC) AS BilledCost,
  CAST(EffectiveCost AS NUMERIC) AS EffectiveCost,
  CAST(ListCost AS NUMERIC) AS ListCost,
  ServiceName,
  ServiceCategory,
  RegionId,
  ResourceId,
  ResourceName,
  ARRAY(
    SELECT AS STRUCT REGEXP_REPLACE(kv.key, r'^user:', '') AS key, kv.value AS value
    FROM UNNEST(Tags.key_value) AS kv
  ) AS Tags
FROM `${raw_dataset}.aws_focus`
