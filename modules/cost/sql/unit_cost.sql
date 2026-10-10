-- What each estate cost per day, and per thousand requests it served.
--
-- A charge belongs to an estate by these rules, in this order.
--
-- GCP charges in the platform project go to the estate in their estate
-- label. Charges with no label are billed to the project rather than to a
-- resource, which in this project means Managed Prometheus and Cloud Logging,
-- and they go to the hub as shared platform overhead.
--
-- AWS and Azure charges with the project tag go to that cloud's estate.
--
-- AWS charges with no tag at all, for the three services the estate runs on,
-- also go to the AWS estate, marked as inferred. Public IPv4 addresses are
-- billed to network interfaces that ECS and the load balancer create, which
-- Terraform never sees, and Fargate tasks carried no tags until the service
-- started passing its own on. Nothing else in the account uses these
-- services, which is what makes the inference safe here and is why it is
-- kept in its own column rather than mixed into the tagged figure.
--
-- Anything else is outside the platform and left out.
--
-- Requests come from the load workflow's record of every request it sent
-- that succeeded. The hub row divides by all three estates' requests, which
-- is the platform overhead per thousand requests served anywhere.
WITH charges AS (
  SELECT
    DATE(ChargePeriodStart) AS day,
    ProviderName,
    SubAccountId,
    ServiceName,
    BilledCost,
    (SELECT value FROM UNNEST(Tags) WHERE key = 'project' LIMIT 1) AS project_tag,
    (SELECT value FROM UNNEST(Tags) WHERE key = 'estate' LIMIT 1) AS estate_tag
  FROM `${dataset}.focus_all`
  WHERE ChargePeriodStart >= TIMESTAMP('${start_date}')
),

assigned AS (
  SELECT
    day,
    BilledCost,
    CASE
      WHEN ProviderName = 'Google Cloud' AND SubAccountId = '${gcp_project}' THEN IFNULL(estate_tag, 'hub')
      WHEN ProviderName = 'AWS' AND project_tag = '${project_tag}' THEN 'aws'
      WHEN ProviderName = 'AWS' AND project_tag IS NULL AND ServiceName IN (${aws_services}) THEN 'aws'
      WHEN ProviderName = 'Microsoft' AND project_tag = '${project_tag}' THEN 'azure'
    END AS estate,
    CASE
      WHEN ProviderName = 'AWS' AND project_tag IS NULL THEN 'inferred'
      WHEN ProviderName = 'Google Cloud' AND estate_tag IS NULL THEN 'project'
      ELSE 'tagged'
    END AS basis
  FROM charges
),

cost AS (
  SELECT
    day,
    estate,
    SUM(BilledCost) AS cost,
    SUM(IF(basis = 'tagged', BilledCost, 0)) AS tagged_cost,
    SUM(IF(basis = 'inferred', BilledCost, 0)) AS inferred_cost,
    SUM(IF(basis = 'project', BilledCost, 0)) AS project_cost
  FROM assigned
  WHERE estate IS NOT NULL
  GROUP BY 1, 2
),

estate_requests AS (
  SELECT DATE(run_at) AS day, cloud AS estate, SUM(ok) AS requests
  FROM `${raw_dataset}.load_runs`
  GROUP BY 1, 2
),

platform_requests AS (
  SELECT day, SUM(requests) AS requests
  FROM estate_requests
  GROUP BY 1
),

joined AS (
  SELECT
    c.*,
    IF(c.estate = 'hub', p.requests, r.requests) AS requests
  FROM cost AS c
  LEFT JOIN estate_requests AS r USING (day, estate)
  LEFT JOIN platform_requests AS p USING (day)
)

SELECT
  day,
  estate,
  ROUND(cost, 4) AS cost,
  ROUND(tagged_cost, 4) AS tagged_cost,
  ROUND(inferred_cost, 4) AS inferred_cost,
  ROUND(project_cost, 4) AS project_cost,
  requests,
  ROUND(SAFE_DIVIDE(cost, requests) * 1000, 4) AS cost_per_1000_requests
FROM joined
