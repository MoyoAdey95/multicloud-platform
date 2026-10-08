locals {
  log_group_name = "/ecs/${var.name}"
}

# A Fargate cluster is only a namespace. Container Insights stays off because
# its metrics bill per task, and metrics go to the hub instead.
resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

# Created here rather than by the awslogs driver, so it has a retention
# period and is removed on destroy. Container stdout lands here. Once the
# collector is running, the app's logs also go to the hub.
resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = 1
}

# Both sides of a conditional must have the same type in Terraform, and an
# empty list does not match a list of containers. So the full lists are built
# here and slice() keeps all of them or none, depending on whether a
# collector image is set.
locals {
  with_collector = var.collector_image != ""

  app_environment = [
    { name = "CLOUD", value = "aws" },
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://127.0.0.1:4318" },
  ]

  sidecars = [
    # The collector, the same image as in the other two estates. It signs in
    # to Google with the baked-in AWS credential config, which points at the
    # shim below. Not essential, so the app keeps serving if it fails.
    {
      name      = "collector"
      image     = var.collector_image
      essential = false

      environment = [
        { name = "CLOUD", value = "aws" },
        { name = "GOOGLE_APPLICATION_CREDENTIALS", value = "/etc/platform/aws-credential-config.json" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "collector"
        }
      }
    },
    # Serves the task's ECS credentials in the EC2 metadata format Google's
    # library expects. Runs from the app image, which already has Python, so
    # there is no third image to build.
    {
      name      = "credential-shim"
      image     = var.image
      essential = false
      command   = ["python", "-c", file("${path.module}/../../collector/credential_shim.py")]

      environment = [
        { name = "SHIM_MODE", value = "aws" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "credential-shim"
        }
      }
    },
  ]
}

# Nothing to run until an image has been pushed, so the task definition and
# service only exist once an image reference is passed in.
resource "aws_ecs_task_definition" "this" {
  count = var.image == "" ? 0 : 1

  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  # x86_64, because the one image built for all three estates is amd64.
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode(concat([
    {
      name      = "api"
      image     = var.image
      essential = true

      # With a collector next to it, the app also sends its logs there.
      environment = slice(local.app_environment, 0, local.with_collector ? 2 : 1)

      portMappings = [
        { containerPort = var.app_port, protocol = "tcp" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ], slice(local.sidecars, 0, local.with_collector ? 2 : 0)))
}

# One task, always. Fargate behind a load balancer has no scale to zero, so
# this estate has a cost floor the other two do not.
resource "aws_ecs_service" "this" {
  count = var.image == "" ? 0 : 1

  name             = var.name
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.this[0].arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  # Only takes effect for tasks started after it is turned on.
  enable_execute_command = true

  # A public IP so the task can reach ECR and CloudWatch without a NAT
  # gateway. Inbound is still only from the load balancer.
  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "api"
    container_port   = var.app_port
  }

  health_check_grace_period_seconds = 30

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # ECS will not attach a service to a target group with no listener.
  depends_on = [aws_lb_listener.http]

  # CI registers a new revision per deploy, built from the latest revision
  # with only the image swapped. Without this every plan would roll the
  # service back to the revision Terraform registered. The trade-off is that
  # a task definition change made here reaches the service on the next CI
  # deploy, or by hand with update-service, not on apply.
  lifecycle {
    ignore_changes = [task_definition]
  }
}
