# Estate layout

The repo is laid out as a small landing zone. There is a hub and three estates, and each one is its own Terraform root with its own state.

| Root | Holds | State prefix |
|---|---|---|
| envs/hub | Shared GCP resources. Metrics, logs, dashboards, alerts, cost tables and the identity pool the other estates sign in through | multicloud-platform/hub |
| envs/gcp | The service on Cloud Run, its registry and its runtime service account | multicloud-platform/gcp |
| envs/aws | The service on ECS Fargate behind a load balancer, with its VPC, registry and roles | multicloud-platform/aws |
| envs/azure | The service on Container Apps, with its resource group, registry and managed identity | multicloud-platform/azure |

## Why four roots and not one

With one root, a plan for a change to the AWS load balancer would also refresh and could touch every Azure and GCP resource. A typo in one estate could plan a destroy in another. Separate roots make the blast radius one estate. Each can be planned, applied, and destroyed on its own, and each could be handed to a different team without sharing state.

The cost is that values sometimes have to cross between roots. The hub needs to know the AWS task role and the Azure identity to trust them. Where that happens it is read from the other root's outputs, and the dependency is one way only. Estates never read from each other.

## What is the same in every estate

The same image. It is built once for linux/amd64 and pushed to Artifact Registry, ECR and ACR by `scripts/publish-image.sh`, which reads the digest back from all three and fails if they differ. Each estate runs it pinned by digest, so the code is identical down to the byte. amd64 is used because Container Apps runs nothing else.

The same tags, from `docs/tagging-standard.md`, with `estate` set by the root.

The same health path, `/health`, and the same port, 8080.

## What differs, and why it stays different

Each estate uses the provider's own way of running a container, rather than forcing the three into the same shape.

| | GCP | AWS | Azure |
|---|---|---|---|
| Runs on | Cloud Run | ECS Fargate | Container Apps, Consumption |
| In front of it | Google's own frontend | An application load balancer | The environment's built-in ingress |
| Scales to zero | Yes | No | Yes |
| Network | None to manage | VPC, two public subnets, no NAT gateway | None, the environment is not joined to a VNet |
| Runs as | Service account with no roles | Task role with no AWS permissions | User-assigned identity with AcrPull only |

The AWS column is the one that stands out. Fargate behind a load balancer keeps one task running and the load balancer bills by the hour, so the AWS estate has a cost floor the other two do not. That is left as it is and measured, because it is the kind of difference the cost comparison is meant to show.

## Nothing crosses on the request path

A request to any estate is served entirely inside that cloud. No estate calls another, and nothing on the request path calls the hub. What does cross provider boundaries is telemetry going to the hub and billing data being read from each provider's export. If the hub goes down, all three services keep serving.

## What a real landing zone would separate further

Here the hub and the GCP estate share one project, and each provider has one account or subscription. A real setup would give the hub its own project, and each estate its own account, subscription or project, with organisation-level policy above them. That is listed in the production deltas. The roots are already split the way the accounts would be, so moving to separate accounts would change provider configuration rather than structure.
