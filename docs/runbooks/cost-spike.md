# Cost spike

An estate's daily cost has jumped, or a provider budget alert has fired. Billing data lags by a day or more, so this always starts after the fact.

## Where is it?

```bash
# cost per estate per day, with the tagged, inferred and project-level split
bq --project_id=multicloud-platform-lab query --use_legacy_sql=false --format=pretty \
  'SELECT * FROM `multicloud-platform-lab.cost_reporting.unit_cost` WHERE day >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) ORDER BY day, estate'

# the same days by provider and service, including anything untagged
bq --project_id=multicloud-platform-lab query --use_legacy_sql=false --format=pretty \
  'SELECT DATE(ChargePeriodStart) AS day, ProviderName, ServiceName,
     (SELECT value FROM UNNEST(Tags) WHERE key = "project" LIMIT 1) AS project,
     ROUND(SUM(BilledCost), 4) AS cost
   FROM `multicloud-platform-lab.cost_reporting.focus_all`
   WHERE ChargePeriodStart >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY))
   GROUP BY 1, 2, 3, 4 HAVING cost > 0.01 ORDER BY 1, cost DESC'
```

If the cost views are older than a day, run `gh workflow run ingest.yml` first. Run the `reconciliation` view before trusting any number, and it should show no difference.

## What usually causes it here

**Something scaled that should not have.** Cloud Run and Container Apps are capped at two instances, and the ECS service at one task, so a spike from scaling is small. Check the request rate panel for traffic nobody sent, such as scanners on the AWS load balancer.

**A charge with no tag.** Untagged spend appears in the second query with a null project. On AWS the expected untagged lines are public IPv4 addresses, and before 10 October, Fargate. Anything else untagged is new and worth finding.

**Something left behind.** A manual test that created resources, or a destroy that failed part way. Drift detection only sees what Terraform manages, so leftovers outside it show up here first.

**Telemetry volume.** Managed Prometheus charges per sample, so a new metric with a high-cardinality label would show as a jump in Cloud Monitoring in the hub. The app labels by route template, not raw path, to stop scanners creating a series per URL.

## Afterwards

The reasoning for what each estate should cost is in [workload cost](../workload-cost.md). If the spike was real spend that should not have happened, it gets a [post-incident review](https://github.com/MoyoAdey95/cloud-incident-runbooks/blob/main/templates/post-incident-review.md) like any other incident.
