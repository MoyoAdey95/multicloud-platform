# The role the plan and drift workflows use in AWS. Describe and List calls
# return configuration, never data, so they are granted with wildcards. Get
# calls are named one by one and limited to this account's roles and
# repositories.
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid = "DescribeAndList"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "ecs:Describe*",
      "ecs:List*",
      "ecr:Describe*",
      "ecr:List*",
      "logs:Describe*",
      "logs:List*",
      "iam:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ReadRoles"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:GetOpenIDConnectProvider",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/*",
      "arn:aws:iam::${local.account_id}:oidc-provider/*",
    ]
  }

  statement {
    sid = "ReadRepositories"
    actions = [
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/*"]
  }
}

module "github_plan_aws" {
  source = "../../modules/github-oidc-aws"

  role_name        = "github-plan"
  role_description = "Assumed by GitHub Actions on pull requests and main to plan the AWS root. Read only."
  github_subject   = local.github_subject
  extra_subjects   = [local.github_pr_subject]
  policy_json      = data.aws_iam_policy_document.plan.json
}
