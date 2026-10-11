# Telemetry federation broken

An estate is serving requests but its metrics or logs have stopped reaching the hub. On the dashboard, one cloud's lines stop while the load workflow still records successful requests for it. There is no alert for missing data because the scale-to-zero estates have none between load runs. This is noticed by eye or from the load results.

The path is app, then collector sidecar, then on AWS and Azure the credential shim, then Google's token exchange, then the hub.

## Is the collector running and what does it say?

```bash
# GCP
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="platform-api" labels.container_name="collector"' --project multicloud-platform-lab --freshness 1h --limit 20

# AWS, collector and shim write to the task's log group
aws logs tail /ecs/platform-api --profile personal --region eu-west-2 --since 1h --filter-pattern '?error ?denied ?credential'

# Azure
az containerapp logs show --name ca-platform-api --resource-group rg-platform-api --container collector --tail 30
az containerapp logs show --name ca-platform-api --resource-group rg-platform-api --container credential-shim --tail 10
```

## What the errors mean

**A 403 or PERMISSION_DENIED from Google** means the exchange worked but the identity lacks the role. The grants live in the hub root in `module.estate_federation`. If they were just changed, wait. A log write from Azure returned 403 for fourteen minutes after the grant was made, while metric writes worked at once.

**An error from the token exchange itself**, such as an invalid subject or a failed condition, means the federated identity no longer matches the provider. On AWS the provider's condition names the task role. If the role was renamed or recreated the hub has to be applied again so it reads the new name from the AWS root's state. On Azure, the condition names the identity's object ID, and a recreated identity gets a new one.

**Connection refused to 127.0.0.1:8099** means the credential shim is not running. It runs from the app image, so a broken app image breaks the shim too.

**Nothing at all in the collector logs** means it is not starting. Check it is in the running task definition or revision. On AWS a new collector image only arrives with the next deploy. See [0008](../adr/0008-ci-owns-images.md).

## Afterwards

Counters reset when a replica restarts, but the start-time fix means the hub picks up the full count again from the next scrape. The gap stays as a gap. If a whole day is missing, the unit cost is not affected, because it divides by the load workflow's own record. See [0006](../adr/0006-request-counts-from-load-runs.md).
