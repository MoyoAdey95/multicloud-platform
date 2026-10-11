# 0007 Policy runs on the plan JSON

## Context

The same rules, tags, least privilege, and nothing open that should not be, apply in all three clouds. Each cloud has its own policy service. AWS service control policies and Config rules, Azure Policy, and GCP organisation policies.

## Decision

The rules are written once in Rego in `policy/` and run with conftest against `terraform show -json` for every root. The plan workflow runs them on every pull request with read-only identities, and a pull request that breaks a rule fails before anything is applied.

## Rejected

Each provider's policy service, which would mean three languages for one set of rules, and which in a personal account mostly needs an organisation the lab does not have. Sentinel, which needs Terraform Cloud.

## Consequences

The rules see what Terraform would build, including provider defaults such as default tags. They do not see anything made outside Terraform, which is what drift detection is for. They are also not a backstop at the cloud level, which the providers' own services would be. The demo pull request found two faults in the first version, a rule that let a missing setting through and a workflow that hid failures, both described in `docs/evidence/plan-and-policy-2026-10-11.txt`.
