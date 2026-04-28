# -----------------------------------------------------------------------------
# NLB Target Group Locals
# -----------------------------------------------------------------------------

locals {
  platform_nlb_target_group_name_prefix = substr("${var.name_prefix}-nlb", 0, 6)
}

# -----------------------------------------------------------------------------
# NLB Target Group
# -----------------------------------------------------------------------------

resource "aws_lb_target_group" "platform_nlb_tcp" {
  name_prefix = local.platform_nlb_target_group_name_prefix
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "alb"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.name_prefix}-nlb-ingress"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Internal Network Load Balancer
# -----------------------------------------------------------------------------

resource "aws_lb" "platform_nlb" {
  name               = "${var.name_prefix}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id

  tags = {
    Name = "${var.name_prefix}-nlb"
  }
}

# -----------------------------------------------------------------------------
# NLB TCP Listener
# -----------------------------------------------------------------------------

resource "aws_lb_listener" "platform_nlb_tcp" {
  load_balancer_arn = aws_lb.platform_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.platform_nlb_tcp.arn
  }
}
