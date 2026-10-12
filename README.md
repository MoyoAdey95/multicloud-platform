# multicloud-platform

The same small service ran on GCP, AWS and Azure as three separate estates, run as one platform. No request crossed from one cloud to another. What crossed was telemetry, billing data, and the identity that let them cross without a single stored key.

The service is trivial. The work is in the platform around it which includes a separate Terraform state for the hub and each estate, keyless sign-in for CI and for the workloads themselves, one set of metrics and logs labelled by cloud, the cost of the same workload on each provider, policy checks against every plan, and a nightly check for drift.

Personal lab, not client or production work. Built and run between 3 and 11 October 2026, then torn down. Nothing here runs now, so the docs and the captures in [docs/evidence](docs/evidence/) are the record of it working.

## Design

```
          GCP estate                 AWS estate                  Azure estate
          Cloud Run                  ECS Fargate + ALB           Container Apps
     app + collector          app + collector + shim      app + collector + shim
             |                          |                           |
             |       workload identity federation, no keys          |
             +--------------------------+---------------------------+
                                        |
                                        v
                               hub (GCP project)
             Managed Prometheus, Cloud Logging, dashboard, alerts
            BigQuery: FOCUS views of all three bills, unit cost per estate
                                        ^
                                        |
              GitHub Actions: deploy, plan and policy, drift, cost ingest,
              load, each with its own identity in each cloud, signed in by OIDC
```

Each estate runs the same image, built once and pushed to all three registries by digest. A collector sidecar scrapes the app, adds a `cloud` label and sends metrics and logs to the hub. On AWS and Azure it signs in to Google by exchanging its own cloud's workload identity, through a small shim that bridges what Google's auth library expects and what Fargate and Container Apps provide.

The cost pipeline from [multicloud-cost-reporting](https://github.com/MoyoAdey95/multicloud-cost-reporting) was copied in and extended with a view that splits each day's spend by estate and divides it by the requests each estate served.

## What's in here

```
envs/
  hub/                 state reader of the estates, federation, telemetry, dashboard, alerts, cost
  gcp/  aws/  azure/   one root per estate, each with its own state
modules/               workload per cloud, OIDC per cloud, estate federation, cost
app/                   the service, FastAPI with Prometheus metrics
collector/             OpenTelemetry Collector config, credential shim, image
cost/ingest/           loaders for the AWS and Azure exports, request counts, load results
policy/                Rego rules and their tests, run against every root's plan
scripts/               image publishing, alert firing test, local policy check
spikes/                the federation experiments run inside Fargate and Container Apps
.github/workflows/     deploy, collector image, load, ingest, plan, drift
docs/                  decisions, runbooks, findings and evidence
```

## Running it

Prerequisites: Terraform 1.15, the gcloud, AWS and Azure CLIs signed in, conftest, and a billing export already running in each provider.

The GCP project and state bucket are made by hand first, see [docs/bootstrap.md](docs/bootstrap.md), as is the AWS account's GitHub OIDC provider, which every repo in the account shares. Each estate is applied twice on a fresh build, once to create its registry and once with the first image digest, and the estates go before the hub, which reads their state, see [docs/adr/0001-four-state-roots.md](docs/adr/0001-four-state-roots.md). Each workflow signs in with identities set as repository variables from the roots' Terraform outputs, read in its steps as `vars.*`. [docs/estate-layout.md](docs/estate-layout.md) describes what each estate contains.

## What it showed

**Three clouds can share one identity model with no stored keys.** GitHub signs in to all three with OIDC. The AWS and Azure workloads write to Google by exchanging their own cloud's identity. Every identity is pinned to an exact subject and deploy. Cost ingest and read-only plan each have their own, so none can do another's job. [docs/identity-decisions.md](docs/identity-decisions.md)

**One query covers three clouds** because the label is added at collection time. One dashboard and two alerts, each firing per cloud, proven on all three estates with [scripts/fire-alerts.sh](scripts/fire-alerts.sh). [docs/observability-decisions.md](docs/observability-decisions.md)

**The shape of the deployment decided the bill, not the provider.** AWS cost about $1.34 a day, almost all of it a load balancer, three public IPv4 addresses, and a task that never stops. Azure cost $0.17 a day for its registry, and GCP nothing measurable. At this traffic, cost per request was a fixed cost divided by a small number. [docs/workload-cost.md](docs/workload-cost.md)

**Policy and drift checks worked across clouds** by reading Terraform's plan rather than each provider's API. A pull request with a non-compliant bucket failed, and three changes made by hand were caught overnight and put back. [docs/adr/0007-policy-on-plan-json.md](docs/adr/0007-policy-on-plan-json.md)

The things that went wrong first time were found by checking each number against a second source. The hub undercounted every replica's first requests, then the fix hid the first error on a long-running replica. More than half the AWS spend carried no tags even though every resource in the code had them. The first policy run passed a pull request it should have failed, twice. Once from a rule that ignored missing settings and once from a workflow that piped failures into `tee` without `pipefail`, which had also been hiding a real Azure plan error. All of it is written up in [docs/closing.md](docs/closing.md) and [docs/production-deltas.md](docs/production-deltas.md), with the decisions in [docs/adr](docs/adr/).

## Cost

From each provider's own billing, after teardown:

| Provider | What ran | Total |
|---|---|---|
| AWS | Fargate estate, load balancer, public IPv4 | $9.80 |
| Azure | Container Apps estate, container registry | $1.20 |
| GCP | Cloud Run estate and the hub | $0.03 |
| **Total** | | **$11.03** |

AWS ran from 4 to 11 October at about $1.34 a full day. Azure's figure is the estate's resource group, and GCP's is the platform project, both from the billing exports. The AWS figure is the account total from Cost Explorer, which also holds the shared billing export bucket, at a fraction of a cent.

## Teardown

Torn down on 11 October 2026. A final ingest ran first and the last cost views were saved, because destroying the hub deletes them. Every workflow was disabled so nothing scheduled could run into a half-deleted estate.

The hub went first, since its plan reads the estates' state, then Azure, AWS and GCP: 52, 20, 33 and 7 resources. Azure's provider failed twice while waiting on a delete that Azure had already done, and a rerun finished each time. Every root ended with an empty state. Checks afterwards found no Cloud Run service or repository in GCP, no cluster, load balancer, log group or network interface in AWS, and no resource group in Azure. The repository variables and secret were deleted. The workflows are disabled rather than removed, so their files and run history stay. [docs/evidence/teardown-2026-10-11.txt](docs/evidence/teardown-2026-10-11.txt)

The project was then deleted with `gcloud projects delete`, which took the state bucket with it and leaves the project recoverable for 30 days.

Two things were left in place. The AWS account's GitHub OIDC provider is shared with other repos, and the billing exports in all three providers existed before this repo and are still collecting.
