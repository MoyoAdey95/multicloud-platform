# Workload cost

The same container ran on Cloud Run, ECS Fargate and Container Apps from 4 October, with the same hourly load against each. This page sets out what each estate cost, what the platform layer around them cost, and why the numbers are different. The figures come from the `unit_cost` view in BigQuery, which is built on each provider's own billing export and reconciles to the cent against a second source for every provider and month. The query output is in `docs/evidence/`.

## The numbers

Full days from 5 to 8 October, before the billing exports' lag makes the latest days partial:

| Estate | Cost per day | Made up of | Per 1,000 requests |
|---|---|---|---|
| AWS | $1.34 | Load balancer about $0.63, three public IPv4 addresses $0.36, the Fargate task about $0.34 | $3.71 to $22.27 |
| Azure | $0.17 | The Basic container registry. Container Apps itself stayed inside the monthly free grant | $0.46 to $2.78 |
| GCP | $0.00 | Cloud Run stayed inside the free tier, and Artifact Registry storage is too small to show | $0 |
| Hub | under $0.01 | Managed Prometheus samples, nothing else measurable | under $0.003 |

Over a 30-day month that is roughly $40 for AWS, $5 for Azure, nothing for GCP and a few pence for the hub.

The cost per thousand requests looks like a measure of efficiency and here it is nothing of the sort. Each estate's daily cost was flat, and the load workflow sent between 60 and 360 requests a day depending on how many of its scheduled runs GitHub actually started. AWS went from $3.71 to $22.27 per thousand requests without anything changing in AWS. At this volume, unit cost is a fixed cost divided by a small number, and the only thing it tells you is how big the fixed cost is.

## Why AWS costs what it does

None of the AWS cost comes from serving requests. It is the price of being ready to serve them. The Application Load Balancer bills for every hour it exists. Each public IPv4 address bills for every hour it is attached, and there are three, two on the load balancer and one on the task, which has a public address so it can pull images without a NAT gateway. The service keeps one task running because a Fargate service behind a load balancer cannot scale to zero.

Cloud Run and Container Apps have neither of those floors. Both put a managed front door in front of the app at no hourly charge and scale to nothing between load runs, so the free grants cover what little they use. The AWS estate is the classic container shape, and AWS has shapes that scale to zero too, but they are not the one most teams reach for when they say ECS.

Azure's $0.17 a day is the container registry, which is Basic tier at about $5 a month whether it holds one image or fifty. Artifact Registry and ECR charge for storage only, and at a few hundred megabytes that rounds to nothing.

## What the platform layer cost

The hub is the part this repo is really about, and it cost almost nothing. Managed Prometheus charges per sample ingested, and three collectors scraping one small app every 30 seconds wrote about a cent's worth a day once all three were running. Cloud Logging stayed inside its free allowance, the dashboard and alert policies have no charge, and BigQuery at this size stays inside the free query and storage tiers.

The cost that a real platform team would worry about is not on this page at all. Telemetry from AWS and Azure leaves those clouds for Google over the internet, and egress from AWS and Azure is billed. At this volume it was too small to appear as its own line, but it grows with traffic and with every metric added.

## Tags and what could not be tagged

Every resource in the code carries the same five tags, and Azure and GCP charges came through with them. On AWS only 48% of the estate's cost did.

Fargate charges are billed against the task, not the service, and the service was not passing its tags on so the compute cost arrived with no tags at all. That is fixed in the code, and tasks started since 10 October carry the tags, but the charges before then stay untagged because tags are applied when a charge is recorded and not retrospectively. The public IPv4 addresses are billed to network interfaces that ECS and the load balancer create for themselves. Terraform never sees those interfaces, so they cannot be tagged at all from here.

The `estate` tag is also missing from every AWS line, because only `project`, `env`, `owner` and `managed-by` were activated as cost allocation tags.

The unit cost view handles the gap openly. Untagged AWS charges for the three services the estate uses are counted against the AWS estate in a separate `inferred_cost` column. That is only safe because nothing else in the account uses those services. In a shared account the honest answer would be to show them as unallocated.

## Counting requests

The plan was to count requests from Managed Prometheus, because scheduled GitHub runs start late or not at all, and the count should be what was actually served. It turned out the hub's own counts could not cover the billing window. The AWS and Azure collectors only went live on 8 October, so there is no count for those estates before then. Until the start-time fix on 9 October, every cold start on GCP lost the requests served before the collector's first scrape, which left 6 October at 228 against 300 sent. Those problems are described in [observability decisions](observability-decisions.md).

The unit cost divides by the load workflow's own record. Every run logs how many requests it sent to each estate and how many succeeded. The ingest job reads those lines back through the GitHub API. Every one of the 24 runs from 5 to 10 October succeeded on all three estates. The Managed Prometheus counts are still loaded as a cross-check, and from 10 October the two should agree, apart from AWS where scanners calling `/` on the public load balancer add requests nobody sent on purpose.

## What this would look like at real traffic

A million requests a day on the AWS estate would cost little more than the $1.34 floor, which works out at about a tenth of a cent per thousand. At that point the comparison would be about compute price, cold starts, and how each platform scales, and the scale-to-zero estates would lose some of their advantage because they would rarely be at zero.
