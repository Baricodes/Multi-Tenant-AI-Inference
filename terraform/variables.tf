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

variable "bedrock_inference_oidc_issuer_url" {
  description = "Optional override for IRSA trust policy issuer. When null, uses the jabari-ai-platform cluster OIDC issuer (requires aws_eks_cluster.jabari_ai_platform)."
  type        = string
  default     = null
  nullable    = true
}

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
    fail).  Script 07_apply-k8s-manifests.sh sets this to true automatically after the Ingress
    is applied and the ALB is provisioned, supplying platform_ingress_alb_arn so Terraform skips
    the tag-based lookup.

    To make the wiring permanent across future runs, add to terraform.tfvars:
      attach_platform_ingress_alb_to_nlb = true
      platform_ingress_alb_arn           = "<arn printed by script 07>"
  EOT
  type        = bool
  default     = false
}
