# -----------------------------------------------------------------------------
# Alarm Configuration Locals
# -----------------------------------------------------------------------------

locals {
  cloudwatch_alarm_actions = [aws_sns_topic.cloudwatch_alerts.arn]

  hpa_alarm_metric_dimensions = var.hpa_alarm_metric_dimensions == null ? {
    ClusterName             = aws_eks_cluster.jabari_ai_platform.name
    Namespace               = var.hpa_alarm_namespace
    horizontalpodautoscaler = var.hpa_alarm_name
  } : var.hpa_alarm_metric_dimensions
}

# -----------------------------------------------------------------------------
# Alarm Notification Topic
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "cloudwatch_alerts" {
  name = "${var.name_prefix}-cloudwatch-alerts"

  tags = {
    Name = "${var.name_prefix}-cloudwatch-alerts"
  }
}

resource "aws_sns_topic_subscription" "cloudwatch_alert_email" {
  count = var.cloudwatch_alarm_email == null ? 0 : 1

  topic_arn = aws_sns_topic.cloudwatch_alerts.arn
  protocol  = "email"
  endpoint  = var.cloudwatch_alarm_email
}

# -----------------------------------------------------------------------------
# Platform Dashboard
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = var.cloudwatch_dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Pod CPU Utilization by Namespace"
          view    = "timeSeries"
          region  = var.aws_region
          period  = 300
          stacked = false
          metrics = [
            [
              {
                expression = "SELECT AVG(pod_cpu_utilization) FROM SCHEMA(\"ContainerInsights\", ClusterName, Namespace, PodName) WHERE ClusterName = '${aws_eks_cluster.jabari_ai_platform.name}' GROUP BY Namespace"
                id         = "q1"
                label      = "Avg pod CPU utilization"
              }
            ]
          ]
          yAxis = {
            left = {
              label = "Percent"
              min   = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Pod Memory Utilization by Namespace"
          view    = "timeSeries"
          region  = var.aws_region
          period  = 300
          stacked = false
          metrics = [
            [
              {
                expression = "SELECT AVG(pod_memory_utilization) FROM SCHEMA(\"ContainerInsights\", ClusterName, Namespace, PodName) WHERE ClusterName = '${aws_eks_cluster.jabari_ai_platform.name}' GROUP BY Namespace"
                id         = "q1"
                label      = "Avg pod memory utilization"
              }
            ]
          ]
          yAxis = {
            left = {
              label = "Percent"
              min   = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway Requests and 5XX Errors"
          view   = "singleValue"
          region = var.aws_region
          period = 300
          metrics = [
            [
              "AWS/ApiGateway",
              "Count",
              "ApiName",
              aws_api_gateway_rest_api.inference.name,
              "Stage",
              aws_api_gateway_stage.prod.stage_name,
              {
                label = "Total Requests"
                stat  = "Sum"
              }
            ],
            [
              ".",
              "5XXError",
              ".",
              ".",
              ".",
              ".",
              {
                label = "5XX Errors"
                stat  = "Sum"
              }
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway Latency P99"
          view   = "singleValue"
          region = var.aws_region
          period = 300
          metrics = [
            [
              "AWS/ApiGateway",
              "Latency",
              "ApiName",
              aws_api_gateway_rest_api.inference.name,
              "Stage",
              aws_api_gateway_stage.prod.stage_name,
              {
                label = "P99 Latency"
                stat  = "p99"
              }
            ]
          ]
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# API Gateway Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "${var.api_gateway_rest_api_name}-${var.api_gateway_stage_name}-5xx"
  alarm_description   = "API Gateway 5XX errors exceeded ${var.api_gateway_5xx_alarm_threshold} in 5 minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = var.api_gateway_5xx_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    ApiName = aws_api_gateway_rest_api.inference.name
    Stage   = aws_api_gateway_stage.prod.stage_name
  }

  tags = {
    Name = "${var.api_gateway_rest_api_name}-${var.api_gateway_stage_name}-5xx"
  }
}

# -----------------------------------------------------------------------------
# EKS Node Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "eks_node_cpu_high" {
  alarm_name          = "${aws_eks_cluster.jabari_ai_platform.name}-node-cpu-high"
  alarm_description   = "Average EKS node CPU utilization exceeded ${var.eks_node_cpu_alarm_threshold_percent}% for 10 minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 10
  datapoints_to_alarm = 10
  threshold           = var.eks_node_cpu_alarm_threshold_percent
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  metric_query {
    id          = "q1"
    expression  = "SELECT AVG(node_cpu_utilization) FROM SCHEMA(\"ContainerInsights\", ClusterName, InstanceId, NodeName) WHERE ClusterName = '${aws_eks_cluster.jabari_ai_platform.name}'"
    label       = "Average node CPU utilization"
    period      = 60
    return_data = true
  }

  tags = {
    Name = "${aws_eks_cluster.jabari_ai_platform.name}-node-cpu-high"
  }
}

# -----------------------------------------------------------------------------
# HPA Saturation Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "hpa_at_max_replicas" {
  alarm_name          = "${var.hpa_alarm_namespace}-${var.hpa_alarm_name}-at-max-replicas"
  alarm_description   = "HPA ${var.hpa_alarm_namespace}/${var.hpa_alarm_name} reached maxReplicas."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  metric_query {
    id          = "e1"
    expression  = "IF(m1 >= m2, 1, 0)"
    label       = "HPA at max replicas"
    return_data = true
  }

  metric_query {
    id = "m1"

    metric {
      namespace   = var.hpa_alarm_metric_namespace
      metric_name = var.hpa_current_replicas_metric_name
      period      = 60
      stat        = "Maximum"
      dimensions  = local.hpa_alarm_metric_dimensions
    }
  }

  metric_query {
    id = "m2"

    metric {
      namespace   = var.hpa_alarm_metric_namespace
      metric_name = var.hpa_max_replicas_metric_name
      period      = 60
      stat        = "Maximum"
      dimensions  = local.hpa_alarm_metric_dimensions
    }
  }

  tags = {
    Name = "${var.hpa_alarm_namespace}-${var.hpa_alarm_name}-at-max-replicas"
  }
}
