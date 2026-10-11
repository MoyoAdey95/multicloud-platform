# 0004 A collector sidecar in each estate

## Context

Metrics and logs from three estates need to reach one place, and every query needs to be able to tell the estates apart.

## Decision

Each estate runs the same OpenTelemetry Collector image as a sidecar next to the app. It scrapes the app's `/metrics`, receives its logs over OTLP on localhost, adds a `cloud` label, and sends everything to the hub. The app itself never knows which cloud it is on, so one image is valid everywhere.

## Rejected

A node agent, because Cloud Run and Container Apps have no nodes to put one on and both scale to zero. Each cloud's native monitoring with a federation layer on top, which would mean three query languages and three sets of alerts that drift apart. Labelling in the queries rather than at collection, which pushes the same relabelling into every panel and alert.

## Consequences

The sidecar starts and stops with the replica it watches, so nothing runs while an estate is at zero. Two problems came from the counters, both found by comparing the app's own `/metrics` with what the hub stored and both fixed. They are described in [observability decisions](../observability-decisions.md). Every replica in an estate scrapes the same local address, so the label set is the same for each, which is fine at one replica and would need a replica ID at more.
