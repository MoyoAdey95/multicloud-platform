# Closing

This repo ran the same small app on Cloud Run, ECS Fargate, and Azure Container Apps for about a week, and built one platform around the three. This page is the summing up. What it cost, what it showed, and when an organisation should actually do this.

## What it cost

Up to 9 October, the last day the billing exports had caught up when the cost views were built, the October bills were $7.94 on AWS, $0.86 on Azure and $0.02 on GCP. Steady state was about $1.34 a day for AWS, $0.17 for Azure and nothing measurable for GCP or the hub. The final figure, from the exports after teardown, is in the README.

Almost all of it was the AWS estate's floor, the load balancer, three public IPv4 addresses, and a task that never stops. None of it was the platform layer. Managed Prometheus, Cloud Logging, BigQuery, the dashboard and the alerts together came to pennies. [Workload cost](workload-cost.md) has the breakdown.

## What it showed

**Three clouds can share one identity model with no stored keys.** GitHub signs in to all three with its OIDC token. The AWS and Azure workloads write to Google by exchanging their own cloud's identity with nothing in between. Every identity is pinned to an exact subject, and each workflow has its own, so deploy, cost ingest and read-only plan cannot do each other's jobs.

**One query can cover three clouds** when the label is added at collection time. The same PromQL drives one dashboard and two alerts, and the alerts were made to fire on all three estates and close again by themselves.

**The unit cost of the same workload is set by the shape of the deployment, not the provider.** At this traffic the cost per thousand requests was a fixed floor divided by a small number. AWS cost eight times Azure because of a load balancer and an always-on task, not because AWS is dear.

**Policy and drift checks work across clouds** when they read Terraform rather than each provider's API. One set of Rego rules checks every root's plan on every pull request, and a nightly plan catches anything changed by hand.

## What building it found

The parts that did not work first time are the most useful parts of the repo. Each one was found by checking a number against a second source rather than trusting it.

The hub was quietly undercounting. The exporter took each replica's first scrape as zero, so the request that woke a scale-to-zero estate never arrived. Then the fix for that hid the first error on a long-running replica, which would have kept the error alert silent. Both were found by comparing the app's own `/metrics` with what the hub stored, and both are fixed.

The hub's own counts could not cover the billing window because the AWS and Azure collectors went live days after the estates did. Cost per request divides by the load workflow's record instead.

More than half the AWS estate's cost carried no tags even though every resource in the code had them. Fargate bills against the task, and the public IPv4 addresses bill against network interfaces Terraform never creates.

The first policy check passed a pull request it should have failed, twice. Once because a rule compared against a setting that was missing rather than wrong, and once because the workflow piped the result into `tee` without `pipefail`. Turning `pipefail` on then showed a real Azure plan error that had been hidden the same way.

All of these are written up, in [observability decisions](observability-decisions.md), [workload cost](workload-cost.md), [production deltas](production-deltas.md) and the evidence files.

## When multicloud is worth it

Running the same thing on three clouds, as this repo does, is almost never the goal. It was a way to put the platform layer under load from three directions at once. The honest reasons an organisation ends up on more than one cloud are narrower.

**An acquisition.** The company bought runs on another cloud, and moving it costs more than running it where it is, at least for a while. This is the most common reason, and it is the case this repo is closest to. Separate workloads, shared identity, telemetry, and cost.

**Data residency or regulation** that one provider cannot meet in a given country, or a customer contract that names a provider.

**A service one provider does genuinely better**, such as BigQuery for analytics or a specific managed AI service, used alongside a main cloud rather than as a reason to spread everything.

What those have in common is that the workloads stay apart. The expensive version of multicloud is the one where a single request crosses providers, paying latency and egress on every call and failing when either side does. This repo kept every request inside one cloud on purpose, see [0005](adr/0005-no-cross-provider-requests.md).

What does not justify it is avoiding lock-in in the abstract, or negotiating leverage on its own. Both are real, but they rarely outweigh running three of everything.

## What I would do differently

I would turn on the collectors at the same time as the estates, not days later, so the hub's own counts covered the whole billing window from the first day. I would write the tests for each policy rule's absent case before writing the rule, and name the shell in every workflow from the start. I would give the hub its own project from day one, because separating it later is harder than starting that way.
