# -----------------------------------------------------------------------------
# Ingress ALB Discovery
# -----------------------------------------------------------------------------

data "aws_lb" "platform_ingress_by_arn" {
  count = var.attach_platform_ingress_alb_to_nlb && var.platform_ingress_alb_arn != null ? 1 : 0
  arn   = var.platform_ingress_alb_arn
}

data "aws_lb" "platform_ingress_by_tag" {
  count = var.attach_platform_ingress_alb_to_nlb && var.platform_ingress_alb_arn == null ? 1 : 0

  tags = {
    "elbv2.k8s.aws/cluster" = aws_eks_cluster.jabari_ai_platform.name
    "ingress.k8s.aws/stack" = var.ingress_group_stack_id
  }

  depends_on = [
    aws_eks_cluster.jabari_ai_platform,
    aws_eks_node_group.jabari_ai_nodes,
  ]
}

# -----------------------------------------------------------------------------
# NLB Target Group Locals
# -----------------------------------------------------------------------------

locals {
  platform_nlb_target_group_name_prefix = substr("${var.name_prefix}-nlb", 0, 6)

  platform_ingress_alb_arn = (
    !var.attach_platform_ingress_alb_to_nlb ? null :
    var.platform_ingress_alb_arn != null ? data.aws_lb.platform_ingress_by_arn[0].arn :
    data.aws_lb.platform_ingress_by_tag[0].arn
  )
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
# NLB to ALB Target Attachment
# -----------------------------------------------------------------------------

resource "aws_lb_target_group_attachment" "platform_nlb_to_ingress_alb" {
  count            = var.attach_platform_ingress_alb_to_nlb ? 1 : 0
  target_group_arn = aws_lb_target_group.platform_nlb_tcp.arn
  target_id        = local.platform_ingress_alb_arn
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
