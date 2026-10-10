-- Azure's actual cost export is not FOCUS, so every column is mapped by hand.
-- The raw table is all text, and the typing happens here.
--
-- The export leaves the billing period columns empty, so the period is taken
-- as the calendar month of the charge date. Dates are written MM/DD/YYYY and
-- each row covers one day. costInBillingCurrency is what was billed after free
-- allowances, and paygCostInBillingCurrency is the pay-as-you-go price, which
-- is FOCUS's ListCost. With no reservations or savings plans, EffectiveCost is
-- the same as BilledCost.
SELECT
  'Microsoft' AS ProviderName,
  billingAccountId AS BillingAccountId,
  SubscriptionId AS SubAccountId,
  subscriptionName AS SubAccountName,
  TIMESTAMP(DATE_TRUNC(PARSE_DATE('%m/%d/%Y', `date`), MONTH)) AS BillingPeriodStart,
  TIMESTAMP(PARSE_DATE('%m/%d/%Y', `date`)) AS ChargePeriodStart,
  TIMESTAMP(DATE_ADD(PARSE_DATE('%m/%d/%Y', `date`), INTERVAL 1 DAY)) AS ChargePeriodEnd,
  CASE chargeType
    WHEN 'Usage' THEN 'Usage'
    WHEN 'Purchase' THEN 'Purchase'
    WHEN 'Refund' THEN 'Credit'
    ELSE 'Adjustment'
  END AS ChargeCategory,
  billingCurrency AS BillingCurrency,
  CAST(CAST(costInBillingCurrency AS FLOAT64) AS NUMERIC) AS BilledCost,
  CAST(CAST(costInBillingCurrency AS FLOAT64) AS NUMERIC) AS EffectiveCost,
  CAST(CAST(paygCostInBillingCurrency AS FLOAT64) AS NUMERIC) AS ListCost,
  meterCategory AS ServiceName,
  CAST(NULL AS STRING) AS ServiceCategory,
  resourceLocation AS RegionId,
  ResourceId,
  REGEXP_EXTRACT(ResourceId, r'[^/]+$') AS ResourceName,
  -- BigQuery's JSON functions need a fixed path, so they cannot look up a key
  -- that is only known per row. Azure writes tags as a flat object of text
  -- values, so each "key":"value" pair is matched as text instead.
  ARRAY(
    SELECT AS STRUCT
      REGEXP_EXTRACT(pair, r'^"([^"]+)"') AS key,
      REGEXP_EXTRACT(pair, r':"([^"]*)"$') AS value
    FROM UNNEST(REGEXP_EXTRACT_ALL(IFNULL(tags, ''), r'"[^"]+":"[^"]*"')) AS pair
  ) AS Tags
FROM `${raw_dataset}.azure_actual`
