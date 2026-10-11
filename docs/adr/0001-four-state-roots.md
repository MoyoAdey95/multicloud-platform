# 0001 Four Terraform roots on one bucket

## Context

The platform spans three clouds and a hub. One Terraform root for everything would mean one plan touching AWS, Azure and GCP at once, every apply needing credentials for all three, and a mistake in one estate able to block or damage another.

## Decision

There are four roots, `envs/hub`, `envs/gcp`, `envs/aws` and `envs/azure`, each with its own state under its own prefix in one GCS bucket, `moyo-platform-tfstate`. The hub reads the estates' outputs with `terraform_remote_state`. No estate reads the hub or another estate.

## Rejected

A single root, for the reasons above. A bucket per root, which adds three bootstraps and buys nothing at this size, since each root's prefix already isolates its state. Remote state in each cloud's own storage, which would have meant three backends and a hub that needs credentials for all of them just to read outputs.

## Consequences

Each root can be planned and applied with one cloud's credentials plus read access to the bucket, which is exactly what the read-only CI identities have. The order matters on a fresh build and on teardown. Estates first, then the hub on the way up, and the hub before the estates on the way down, because the hub holds grants that point at estate identities. The bucket itself is the one thing outside Terraform, described in [bootstrap](../bootstrap.md).
