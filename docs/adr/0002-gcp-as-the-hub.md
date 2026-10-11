# 0002 GCP is the hub

## Context

Telemetry, cost data, and shared tooling need one home. Any of the three clouds could hold it.

## Decision

The hub is the GCP project `multicloud-platform-lab`. It holds Terraform state, Managed Service for Prometheus, Cloud Logging, the dashboard and alerts, and the BigQuery cost datasets. The GCP estate runs in the same project to keep the bootstrap small.

## Rejected

AWS or Azure as the hub. Both could do it, with Amazon Managed Prometheus or Azure Monitor. GCP won on three points. Managed Prometheus needs nothing to run and answers PromQL directly. BigQuery already held the GCP billing export, and the FOCUS pipeline from multicloud-cost-reporting was built on it, and GCP's workload identity federation accepts both AWS and Azure identities natively with an AWS-type provider and an OIDC provider, which is what keeps the estates keyless.

Running the hub's tools ourselves, for example Prometheus and Grafana on a VM, was rejected because it adds something to patch and keep alive for no gain at this size.

## Consequences

Telemetry from AWS and Azure leaves those clouds over the internet, and egress is billed. At this volume it was too small to appear in the bill, but it grows with traffic and is covered in [workload cost](../workload-cost.md). The hub sharing a project with the GCP estate means their costs are told apart by the `estate` label, and unlabelled project charges are treated as hub overhead. A real landing zone would give the hub its own project, which is in the production deltas.
