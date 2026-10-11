# 0003 Federation everywhere, no stored keys

## Context

CI deploys to three clouds, and the AWS and Azure workloads write telemetry into GCP. Every one of those needs an identity in a cloud it does not run in. The usual shortcut is a key or secret stored somewhere.

## Decision

Nothing in this repo signs in with a stored key. GitHub Actions signs in to all three clouds with its OIDC token. The AWS task role and the Azure managed identity sign in to GCP by exchanging their own cloud's identity through GCP workload identity federation, and the Google roles are granted to those federated principals directly, with no service account in between.

GCP has two pools. `github` trusts GitHub Actions. `estates` trusts the AWS task role and the Azure identity. Every identity is pinned to an exact subject, the repository's immutable ID form for GitHub, the role name for AWS, and the tenant and object ID for Azure.

## Rejected

Service account keys or access keys in GitHub secrets, which are long-lived, copyable and need rotating. One pool for both, which would put CI trust and workload trust in the same place, so a change to one could widen the other.

## Consequences

Both workloads needed a small credential shim on localhost, because Google's auth library expects the EC2 metadata endpoint and Fargate does not have one, and expects a plain token endpoint where Container Apps needs an extra header. The details and the experiments are in [identity decisions](../identity-decisions.md). There are now separate identities for deploy, cost ingest, and read-only plan in each cloud, so no workflow can do another's job. The policy rules in `policy/iam.rego` deny service account keys outright.
