# A VPC with two public subnets and nothing else. An application load
# balancer will not create with fewer than two availability zones.
#
# There is no NAT gateway and no private subnet. A NAT gateway bills by the
# hour whether or not anything uses it, and the task can reach ECR and
# CloudWatch through the internet gateway with its own public IP instead.
# Inbound traffic to the task is still limited to the load balancer by
# security group.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# map_public_ip_on_launch stays false. Whether a task gets a public IP is set
# on the ECS service, so nothing else launched here picks one up by accident.
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-public-${local.azs[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# The load balancer takes HTTP from anywhere and can only talk to the task.
# The task takes traffic only from the load balancer's group, by group ID,
# so nothing else can reach it even though it has a public IP. Rules are
# separate resources because the two groups refer to each other.
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Load balancer. HTTP in from the internet, app port out to tasks only."
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-alb"
  }
}

resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks"
  description = "ECS tasks. App port in from the load balancer only, HTTPS out."
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-tasks"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "App port to tasks, for forwarding and health checks"
  referenced_security_group_id = aws_security_group.tasks.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "App port from the load balancer only"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

# HTTPS out covers ECR and CloudWatch Logs now, and the collector pushing to
# Google's APIs later.
resource "aws_vpc_security_group_egress_rule" "tasks_https" {
  security_group_id = aws_security_group.tasks.id
  description       = "HTTPS out to cloud APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Managing the default group with no rules strips the allow-all rules every
# VPC is created with, so anything launched without a group gets nothing.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-default-locked"
  }
}
