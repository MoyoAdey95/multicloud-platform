# The cost ingest workflow reads the FOCUS export and nothing else. The export
# and its bucket were set up by hand before this repo, so they are referred to
# by name and never managed here. ListBucket is limited to the export prefix,
# so the role cannot see what else is in the bucket.
data "aws_iam_policy_document" "cost_export_read" {
  statement {
    sid       = "ListExportPrefix"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.aws_export_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.aws_export_prefix}/*"]
    }
  }

  statement {
    sid       = "ReadExportObjects"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.aws_export_bucket}/${var.aws_export_prefix}/*"]
  }
}

module "github_cost_ingest_aws" {
  source = "../../modules/github-oidc-aws"

  role_name        = "github-cost-ingest"
  role_description = "Assumed by GitHub Actions on main to read the AWS cost export."
  github_subject   = local.github_subject
  policy_json      = data.aws_iam_policy_document.cost_export_read.json
}
