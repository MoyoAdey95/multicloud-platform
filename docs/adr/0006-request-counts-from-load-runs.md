# 0006 Cost per request uses the load workflow's record

## Context

Cost per thousand requests needs a request count per estate per day. The plan was to take it from Managed Prometheus, because scheduled GitHub runs start late or not at all. The count should be what was served, not what was meant to be sent.

## Decision

The unit cost view divides by `cost_raw.load_runs`, built from the load workflow's own log lines, which record what each run sent to each estate and how many requests succeeded. The Managed Prometheus counts are still loaded into `requests_daily` as a cross-check.

## Rejected

Managed Prometheus as the source. When the cost pipeline was built, the hub's counts could not cover the billing window. The AWS and Azure collectors went live on 8 October, so there was nothing for those estates before then, and cold starts on GCP were undercounted until the start-time fix on 9 October.

## Consequences

The count excludes requests the load workflow did not send, such as manual tests and scanners on the public load balancer. That is what the unit cost should measure since the cost is for serving the test traffic. Evidence of both sources side by side is in `docs/evidence/cost-pipeline-2026-10-10.txt`, and the reasoning is in [workload cost](../workload-cost.md).
