# HTTP only. There is no domain for this lab, so there is no certificate for
# an HTTPS listener. That is listed in the production deltas.
#
# This is the part of the AWS estate that cannot scale to zero. The load
# balancer bills by the hour from the moment it exists.

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]

  drop_invalid_header_fields = true
}

# Fargate tasks get their own network interface, so targets are registered
# by IP.
resource "aws_lb_target_group" "this" {
  name        = var.name
  target_type = "ip"
  protocol    = "HTTP"
  port        = var.app_port
  vpc_id      = aws_vpc.this.id

  # The default 300 seconds makes every deploy and destroy wait five minutes.
  deregistration_delay = 30

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
