# Bootstrap: what exists before Terraform runs

A few things have to exist before `terraform init` can run in any of the four roots, so they sit outside Terraform. This page records how each was built and gives the CLI commands to build the same thing from scratch.

## The GCP project

Everything on the GCP side lives in one project, `multicloud-platform-lab`. It holds the hub (state, metrics, logs, dashboards, alerts and cost tables) and the GCP estate. A real landing zone would give the hub and the estate a project each. Keeping them together here means one project to create and one to delete at the end, and the split is listed in the production deltas.

I created it in the console with no organisation and linked it to my existing billing account. The account's budgets with no project filter cover it without any change.

The Cloud Billing export is not moved here. It stays in the project it was switched on in and is read from there because pointing an export at a new place starts it again with no history.

## The state bucket

I built the bucket in the console. The settings below were read back afterwards with `gcloud storage buckets describe`.

| Setting | Value |
|---|---|
| Name | moyo-platform-tfstate |
| Location | europe-west2, single region |
| Storage class | Standard |
| Access control | Uniform bucket-level access |
| Public access prevention | Enforced |
| Object versioning | Enabled |
| Lifecycle | Delete a noncurrent version once 5 newer ones exist, or 30 days after it became noncurrent |
| Soft delete | 7 days, the default |
| Encryption | Google-managed keys |
| Labels | project=multicloud-platform, env=dev, owner=moyo, managed-by=console-bootstrap |

When versioning is ticked in the console it also adds two lifecycle rules, keeping one old version for one day. For Terraform state that is too little. Every apply writes a new version, so a bad apply noticed the next morning after another apply would already have lost the good state. I changed the rules to 5 versions and 30 days. The CLI adds no rules when versioning is turned on so the commands below set them explicitly.

Uniform access means permissions come from IAM on the bucket alone, with no per-object ACLs to audit.

## Four roots, one bucket

Each root under `envs/` keeps its state under its own prefix.

| Root | Prefix |
|---|---|
| hub | multicloud-platform/hub |
| gcp | multicloud-platform/gcp |
| aws | multicloud-platform/aws |
| azure | multicloud-platform/azure |

A plan in one root cannot see or change another root's resources. Each estate can be destroyed on its own. All four backends sign in to the bucket with gcloud application default credentials, including the AWS and Azure roots, so running the AWS root needs both an AWS session and a gcloud login.

The gcs backend writes a lock file next to the state object while a run is in progress. Cloud Storage only creates an object if it does not already exist when asked to, so two runs cannot both take the lock and no lock table is needed. A run that dies holding the lock can be cleared with `terraform force-unlock`.

## AWS and Azure

AWS needs one thing in place that Terraform here does not manage. An account can only have one IAM OIDC provider for `token.actions.githubusercontent.com`, and it already exists in the account. It was created by hand and tagged `managed-by=console-bootstrap`. The AWS root looks it up with a data source and never creates or destroys it.

Azure needs nothing beyond the subscription. The Azure estate's resource group is created by Terraform.

## Building it with the CLI

The bucket commands were tested on a throwaway bucket, `moyo-platform-bootstrap-test` which came out with the same settings as the real one and was then deleted. The project commands were not tested. A deleted project stays pending deletion for 30 days and still counts against the account's project quota, so creating one just to prove the commands was not worth it.

Project IDs and bucket names are global, so change them to something unused. `BILLING_ACCOUNT_ID` comes from `gcloud billing accounts list`.

```bash
gcloud projects create multicloud-platform-lab --name="Multicloud Platform Lab"

gcloud billing projects link multicloud-platform-lab --billing-account=BILLING_ACCOUNT_ID

cat > lifecycle.json <<'JSON'
{"rule": [
  {"action": {"type": "Delete"}, "condition": {"isLive": false, "numNewerVersions": 5}},
  {"action": {"type": "Delete"}, "condition": {"daysSinceNoncurrentTime": 30}}
]}
JSON

gcloud storage buckets create gs://moyo-platform-tfstate \
  --project=multicloud-platform-lab --location=europe-west2 \
  --default-storage-class=STANDARD \
  --uniform-bucket-level-access --public-access-prevention

gcloud storage buckets update gs://moyo-platform-tfstate \
  --versioning --lifecycle-file=lifecycle.json \
  --update-labels=project=multicloud-platform,env=dev,owner=moyo,managed-by=cli-bootstrap
```

Soft delete is not set explicitly. New buckets get a 7 day policy by default, and the test bucket showed the same 604800 seconds as the real one.

Resources built this way get `managed-by=cli-bootstrap`. The label records how the resource came to exist.

Once the bucket exists, `terraform init` from any root under `envs/` connects to it.
