# ECS uses two roles. The execution role is used by the ECS agent before the
# container starts, to pull the image and set up logging. The task role is
# what the containers run as once they are up.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  region        = data.aws_region.current.region
  log_group_arn = "arn:aws:logs:${local.region}:${local.account_id}:log-group:${local.log_group_name}"
}

# Limited to ECS tasks in this account, so another account's tasks cannot
# assume the roles through the service.
data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ecs:${local.region}:${local.account_id}:*"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-task-execution"
  description        = "Used by ECS to pull the image and write container logs."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

# Written out instead of attaching AmazonECSTaskExecutionRolePolicy, which
# allows every repository and every log group in the account. This allows
# one of each. GetAuthorizationToken has no resource to scope to.
data "aws_iam_policy_document" "execution" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PullImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [aws_ecr_repository.this.arn]
  }

  statement {
    sid = "WriteLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${local.log_group_arn}:*"]
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "pull-image-and-write-logs"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

# No permissions in AWS, and it will not need any. Its job later is to be
# the identity the collector exchanges for a short-lived Google token, and
# the trust for that is set up on the Google side.
resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  description        = "Runtime identity of the task. No AWS permissions."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}
