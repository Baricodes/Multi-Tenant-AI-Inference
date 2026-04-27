# -----------------------------------------------------------------------------
# Core / Global
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for resource Name tags."
  type        = string
  default     = "mtai"
}

# -----------------------------------------------------------------------------
# IRSA / IAM
# -----------------------------------------------------------------------------

variable "bedrock_inference_oidc_issuer_url" {
  description = "Optional override for IRSA trust policy issuer. When null, uses the jabari-ai-platform cluster OIDC issuer (requires aws_eks_cluster.jabari_ai_platform)."
  type        = string
  default     = null
  nullable    = true
}

# -----------------------------------------------------------------------------
# NLB / ALB Wiring
# -----------------------------------------------------------------------------

variable "platform_ingress_alb_arn" {
  description = <<-EOT
    Optional ARN of the internal Application Load Balancer created by AWS Load Balancer Controller for the shared Ingress.
    When set, Terraform skips tag-based lookup. When null, Terraform expects an ALB tagged
    elbv2.k8s.aws/cluster = jabari-ai-platform name and ingress.k8s.aws/stack = ingress_group_stack_id
    (deploy the Ingress before apply, or set this ARN from the console / CLI after the ALB exists).
  EOT
  type        = string
  default     = null
  nullable    = true
}

variable "ingress_group_stack_id" {
  description = "Must match alb.ingress.kubernetes.io/group.name and the ingress.k8s.aws/stack tag on the LBC-managed ALB."
  type        = string
  default     = "jabari-ai-platform"
}

variable "attach_platform_ingress_alb_to_nlb" {
  description = <<-EOT
    When true, discovers the LBC-managed internal ALB (by platform_ingress_alb_arn or by tags)
    and registers it with the NLB target group so API Gateway VPC Link traffic is forwarded to
    the tenant services.

    Leave false for the initial `terraform apply` (the ALB does not exist yet; data.aws_lb would
    fail).  Script 06_apply-k8s-manifests.sh sets this to true automatically after the Ingress
    is applied and the ALB is provisioned, supplying platform_ingress_alb_arn so Terraform skips
    the tag-based lookup.

    To make the wiring permanent across future runs, add to terraform.tfvars:
      attach_platform_ingress_alb_to_nlb = true
      platform_ingress_alb_arn           = "<arn printed by script 06>"
  EOT
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# API Gateway
# -----------------------------------------------------------------------------

variable "api_gateway_vpc_link_name" {
  description = "Name for the API Gateway REST API VPC Link."
  type        = string
  default     = "jabari-ai-platform-vpclink"
}

variable "api_gateway_rest_api_name" {
  description = "Name for the API Gateway REST API."
  type        = string
  default     = "jabari-ai-inference-api"
}

variable "api_gateway_stage_name" {
  description = "Deployment stage name for the API Gateway REST API."
  type        = string
  default     = "prod"

  validation {
    condition     = var.api_gateway_stage_name == "prod"
    error_message = "The API Gateway stage name must be prod."
  }
}

# -----------------------------------------------------------------------------
# Tenant-A Throttling and Quotas
# -----------------------------------------------------------------------------

variable "tenant_a_usage_plan_name" {
  description = "Usage plan name for tenant-a."
  type        = string
  default     = "tenant-a-plan"
}

variable "tenant_a_api_key_name" {
  description = "API key name for tenant-a."
  type        = string
  default     = "tenant-a-key"
}

variable "tenant_a_throttle_rate_limit" {
  description = "Steady-state request rate limit for tenant-a, in requests per second."
  type        = number
  default     = 100
}

variable "tenant_a_throttle_burst_limit" {
  description = "Burst request limit for tenant-a."
  type        = number
  default     = 200
}

variable "tenant_a_monthly_quota_limit" {
  description = "Monthly request quota for tenant-a."
  type        = number
  default     = 1000000
}

# -----------------------------------------------------------------------------
# Tenant-B Throttling and Quotas
# -----------------------------------------------------------------------------

variable "tenant_b_usage_plan_name" {
  description = "Usage plan name for tenant-b."
  type        = string
  default     = "tenant-b-plan"
}

variable "tenant_b_api_key_name" {
  description = "API key name for tenant-b."
  type        = string
  default     = "tenant-b-key"
}

variable "tenant_b_throttle_rate_limit" {
  description = "Steady-state request rate limit for tenant-b, in requests per second."
  type        = number
  default     = 100
}

variable "tenant_b_throttle_burst_limit" {
  description = "Burst request limit for tenant-b."
  type        = number
  default     = 200
}

variable "tenant_b_monthly_quota_limit" {
  description = "Monthly request quota for tenant-b."
  type        = number
  default     = 1000000
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboards and Alarms
# -----------------------------------------------------------------------------

variable "cloudwatch_dashboard_name" {
  description = "Name for the CloudWatch dashboard."
  type        = string
  default     = "jabari-ai-platform"
}

variable "cloudwatch_alarm_email" {
  description = "Optional email address to subscribe to CloudWatch alarm SNS notifications."
  type        = string
  default     = null
  nullable    = true
}

variable "api_gateway_5xx_alarm_threshold" {
  description = "API Gateway 5XX count threshold over 5 minutes."
  type        = number
  default     = 10
}

variable "eks_node_cpu_alarm_threshold_percent" {
  description = "Average EKS node CPU utilization threshold for the 10-minute alarm."
  type        = number
  default     = 80
}

# -----------------------------------------------------------------------------
# HPA Alarm
# -----------------------------------------------------------------------------

variable "hpa_alarm_namespace" {
  description = "Kubernetes namespace for the HPA maxReplicas alarm."
  type        = string
  default     = "tenant-a"
}

variable "hpa_alarm_name" {
  description = "Kubernetes HPA name for the maxReplicas alarm."
  type        = string
  default     = "summarizer-hpa"
}

variable "hpa_alarm_metric_namespace" {
  description = "CloudWatch namespace where HPA metrics are published."
  type        = string
  default     = "ContainerInsights/Prometheus"
}

variable "hpa_current_replicas_metric_name" {
  description = "CloudWatch metric name for the HPA current replica count."
  type        = string
  default     = "kube_horizontalpodautoscaler_status_current_replicas"
}

variable "hpa_max_replicas_metric_name" {
  description = "CloudWatch metric name for the HPA max replica count."
  type        = string
  default     = "kube_horizontalpodautoscaler_spec_max_replicas"
}

variable "hpa_alarm_metric_dimensions" {
  description = "Optional override for HPA metric dimensions if the published CloudWatch dimensions differ from the defaults."
  type        = map(string)
  default     = null
  nullable    = true
}
