# Lets one GitHub repository's workflows assume an AWS role without a stored
# access key. The role's permissions come in from the caller, so another repo
# can copy the folder and use it as it is.

# An account can only hold one OIDC provider per issuer URL, so neither this
# repo nor any other owns it. It was created by hand as account bootstrap and
# is looked up here.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Only tokens carrying one of the exact subjects can assume the role. The
# main subject includes the ref, so another branch or any other repository is
# refused. A pull request subject is only added for read-only roles.
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = concat([var.github_subject], var.extra_subjects)
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.role_description
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.role_name}-permissions"
  role   = aws_iam_role.this.id
  policy = var.policy_json
}
