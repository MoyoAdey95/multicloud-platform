# A second workload identity pool, separate from the one GitHub Actions uses.
# This one is for the workloads themselves. The collector running next to
# the app on AWS or Azure presents that cloud's own identity, and Google
# swaps it for a short-lived token. No key is created or stored anywhere.
#
# Kept apart from the GitHub pool so the two sets of trust can be read,
# changed and removed independently.

resource "google_iam_workload_identity_pool" "this" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "Estates"
  description               = "Workloads in the AWS and Azure estates sending telemetry to the hub."
}

# Provider IDs need at least four characters, so "aws-estate" rather than
# "aws". AWS has its own provider type. The caller signs a GetCallerIdentity request
# with its AWS credentials and Google checks that signature with AWS, so
# there is no OIDC issuer involved.
#
# The ARN a task presents is the assumed-role session ARN, which changes per
# task. attribute.aws_role strips the session part, so the condition can name
# the role itself.
resource "google_iam_workload_identity_pool_provider" "aws" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = "aws-estate"
  display_name                       = "AWS estate"

  aws {
    account_id = var.aws_account_id
  }

  attribute_mapping = {
    "google.subject"     = "assertion.arn"
    "attribute.aws_role" = "assertion.arn.contains('assumed-role') ? assertion.arn.extract('{account_arn}assumed-role/') + 'assumed-role/' + assertion.arn.extract('assumed-role/{role_name}/') : assertion.arn"
  }

  # Any role in the account could otherwise sign in. Only the task role of
  # the AWS estate is let through.
  attribute_condition = "attribute.aws_role == '${local.aws_assumed_role}'"
}

locals {
  # The form the mapping above produces for the task role.
  aws_assumed_role = "arn:aws:sts::${var.aws_account_id}:assumed-role/${var.aws_task_role_name}"

  aws_principal = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.this.name}/attribute.aws_role/${local.aws_assumed_role}"
}

# Granted to the federated identity directly rather than through a service
# account it impersonates. Each estate then shows up as itself in Google's
# audit logs, and there is no service account key or impersonation chain to
# manage. Write only. Neither role can read metrics or logs back.
resource "google_project_iam_member" "aws_telemetry" {
  for_each = toset(var.telemetry_roles)

  project = var.project_id
  role    = each.value
  member  = local.aws_principal
}
