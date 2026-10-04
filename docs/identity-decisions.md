# Identity decisions

Nothing in this repo signs in with a stored key. Every identity is either a platform identity that the cloud issues to a running workload, or a short-lived token from a federation exchange. This page lists every principal, what it can do, and how it gets its credentials.

## Every principal

| Principal | Where | Signs in with | Can do |
|---|---|---|---|
| Me, running Terraform | My Mac | gcloud ADC, AWS SSO profile, az login | Apply all four roots |
| github-deploy-gcp | GCP service account | GitHub OIDC through the `github` pool, main branch only | Push to one Artifact Registry repo, deploy one Cloud Run service, act as its runtime account |
| github-deploy-aws | IAM role | GitHub OIDC, trust on the exact main-branch subject | Push to one ECR repo, register task definitions, update one service, pass the two task roles to ECS |
| id-github-deploy-azure | User-assigned identity | GitHub OIDC through a federated credential | AcrPush on one registry, Container Apps Contributor on one app |
| platform-api-run | GCP service account | Attached to the Cloud Run service | Nothing yet. Gets metric and log writing with the collector |
| platform-api-task | IAM role | Attached to the ECS task | The four ECS Exec actions in AWS. In Google, metric and log writing through the `estates` pool |
| id-platform-api | User-assigned identity | Attached to the container app | AcrPull on one registry. In Google, metric and log writing through the `estates` pool |

The GitHub subject is the immutable form, `repo:MoyoAdey95@212127446/multicloud-platform@1404214134:ref:refs/heads/main`, read from the GitHub API. A renamed or recreated repo with the same name gets different IDs and is not trusted.

## Two pools, not one

GCP has two workload identity pools. `github` trusts GitHub Actions. `estates` trusts the AWS task role and the Azure managed identity. Keeping them apart means the trust for CI and the trust for running workloads can be read, changed, and removed separately.

## Workloads writing to the hub

The AWS and Azure workloads write metrics and logs into the hub in GCP. Both do it by exchanging their own cloud's identity for a Google token.

On AWS the pool has an AWS-type provider. The caller signs an STS GetCallerIdentity request with its AWS credentials, and Google checks the signature with AWS. A condition on the role, with the per-task session part stripped off, lets in only `platform-api-task`.

On Azure the pool has an OIDC provider for the tenant's v2.0 issuer. The managed identity asks for a token with the audience `api://AzureADTokenExchange`, which Entra only accepts for exchanges like this, so the token is no use against Azure's own APIs. A condition on tenant and subject lets in only `id-platform-api`.

The Google roles are granted to those federated identities directly, not to a service account they impersonate. Each estate then appears as itself in Google's audit logs and there is no impersonation chain to manage. The roles are Metric Writer and Log Writer, which write but cannot read back.

## What the experiments found

Both clouds needed a small local shim between the workload and Google's auth library, for different reasons.

On Fargate, the library looks for AWS credentials in environment variables or at the EC2 metadata address 169.254.169.254. A Fargate task has neither. It gets credentials from the ECS endpoint at 169.254.170.2 instead. With the credential config exactly as gcloud generates it, the exchange failed with a connection error to 169.254.169.254. The config's credential URL can point anywhere, so it now points at a shim on localhost that reads the ECS endpoint and answers in the EC2 metadata format which uses the same field names. The region comes from `AWS_REGION`, which Fargate sets.

On Container Apps, the managed identity endpoint is not the VM metadata address either. It is in `IDENTITY_ENDPOINT` and needs a per-container header from `IDENTITY_HEADER`. A credential config file cannot read an environment variable, so a shim on localhost adds the header and hands the token to the library.

Some values had to come from a real token rather than from documentation. The Azure token's audience is the application ID `fb60f99c-7a34-4190-8149-302f77469936`, not the `api://AzureADTokenExchange` URI that was asked for, and its subject is the identity's object ID. A provider built from the URI would have rejected every token.

Two smaller things. The Azure token lives for about 24 hours, against an hour for the AWS session credentials. A grant made seconds before it is used can fail. The Azure log write returned 403 straight after the apply and 200 fourteen minutes later with nothing changed, while the metric write from the same apply worked at once.

The scripts are in `spikes/` and the outputs will be in `docs/evidence/`.

## What was left out

ECS Exec is on so the spike could run inside the task. That gives the task role four Session Manager actions it would not otherwise need. In production it would be off, and it is listed in the production deltas.

There is still one long-lived credential in the picture on my Mac. The AWS SSO session, gcloud ADC, and az login all refresh themselves, but they belong to a person with broad rights in all three accounts. In a real setup only CI would apply, and people would have read access.
