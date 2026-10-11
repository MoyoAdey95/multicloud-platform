# 0005 No request crosses a provider boundary

## Context

A multicloud platform can mean one application spread across clouds, with a request entering one provider and calling another. Or it can mean separate workloads in separate clouds sharing identity, telemetry and cost.

## Decision

Each estate serves the same app on its own, from start to finish. What crosses between clouds is telemetry, billing data, and identity, but never a user request.

## Rejected

A request path across providers, for example the front end on GCP calling compute on AWS. Every hop would add latency and billed egress to every request, and the service would fail when any one provider did.

## Consequences

This keeps each estate's cost and failure its own. Measuring what a provider boundary costs on the request path is a separate experiment, deliberately left out of this repo.
