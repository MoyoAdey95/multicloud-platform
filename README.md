# multicloud-platform

The same small service running on GCP, AWS and Azure as three separate estates, run as one platform. No request crosses from one cloud to another. What crosses is telemetry, billing data, and the identity that lets it cross without storing any keys.

The service is deliberately trivial. The work is in the platform layer around it. A separate Terraform state for the hub and for each estate, keyless sign-in for CI and for the workloads themselves, one set of metrics and logs labelled by cloud, the cost of the same workload on each provider, and policy checks that run against all three.

Status: in progress.
