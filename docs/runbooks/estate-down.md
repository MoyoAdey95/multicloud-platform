# Estate down

One estate is failing while the other two are fine. The error ratio alert names the cloud in its subject, and the dashboard's `cloud` filter narrows every panel to it.

## First, is it really one estate?

Compare all three on the dashboard. If all three fail together, the cause is shared. Most likely the app image since the same digest runs everywhere. Then this is a bad deploy, and the [rollback checklist](https://github.com/MoyoAdey95/cloud-incident-runbooks/blob/main/checklists/rollback.md) applies to all three estates at once.

If only one fails the cause is in that cloud.

## Read-only checks

```bash
# which image is each estate running? They should all be the same digest
gcloud run services describe platform-api --project multicloud-platform-lab --region europe-west2 --format='value(spec.template.spec.containers[0].image)'
aws ecs describe-services --profile personal --region eu-west-2 --cluster platform-api --services platform-api --query 'services[0].{td:taskDefinition, running:runningCount, rollout:deployments[0].rolloutState}'
az containerapp show --name ca-platform-api --resource-group rg-platform-api --query '{image:properties.template.containers[0].image, revision:properties.latestRevisionName, state:properties.runningStatus}'

# what are the app's own errors?
gcloud logging read 'logName="projects/multicloud-platform-lab/logs/platform-api" severity>=ERROR' --project multicloud-platform-lab --freshness 1h --limit 20
```

The last command reads all three estates' app logs from the hub labelled by cloud, so it works even when you cannot sign in to the failing cloud.

## By cloud

**GCP.** Cloud Run's own runbook covers it: [Cloud Run 5xx spike](https://github.com/MoyoAdey95/cloud-incident-runbooks/blob/main/runbooks/01-cloud-run-5xx-spike.md). Traffic can be moved back to the previous revision without a deploy.

**AWS.** A task that keeps restarting looks like [a container restart loop](https://github.com/MoyoAdey95/cloud-incident-runbooks/blob/main/runbooks/02-container-restart-loop.md), with `aws ecs describe-tasks` and the `/ecs/platform-api` log group in place of `docker`. Check the target group's health too, since the load balancer stops sending traffic to a task that fails its health check on `/health`. The deployment circuit breaker rolls a failed deploy back by itself, so a `rolloutState` of `FAILED` means the old task is still serving.

**Azure.** Container Apps can show the app as running while a new revision is failing to start. Check the revision list and its replica counts. Azure takes 26 to 28 seconds to cold start, which the load workflow's `first_s` records, so one slow first request after a quiet hour is normal and not an outage.

## Recovery

Redeploy the last good digest with `gh workflow run deploy.yml` from the commit that built it, or move traffic back to the previous revision on GCP and Azure. Do not change the service in the console. Drift detection will report it the next night, and the next apply would undo it.
