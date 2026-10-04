module "workload" {
  source = "../../modules/workload-fargate"

  name     = "platform-api"
  vpc_cidr = "10.40.0.0/16"
  image    = var.image
}

# What the deploy role may do. Push to the one repository, register task
# definitions, update the one service, and pass the two task roles to ECS and
# nothing else.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PushImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [module.workload.repository_arn]
  }

  # These two cannot be limited to one task definition family.
  statement {
    sid = "TaskDefinitions"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid = "DeployService"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = [module.workload.service_arn]
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = [module.workload.execution_role_arn, module.workload.task_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

module "github_oidc_aws" {
  source = "../../modules/github-oidc-aws"

  role_name        = "github-deploy-aws"
  role_description = "Assumed by GitHub Actions on main to push the image and deploy the AWS estate."
  github_subject   = local.github_subject
  policy_json      = data.aws_iam_policy_document.deploy.json
}
