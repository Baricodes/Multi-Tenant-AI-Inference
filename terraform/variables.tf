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
    When true, discovers the LBC internal ALB (by ARN or tags) and registers it with the NLB target group.
    Default false so terraform apply can succeed before the LBC has created the ALB (data.aws_lb would otherwise return 0 results).
    After the shared Ingress is applied and the ALB exists, set this to true, or set platform_ingress_alb_arn, and re-apply.
    When the target group is replaced (name_prefix change), set true in the same apply so the new group receives the ALB attachment; otherwise re-register the ALB target manually.
  EOT
  type        = bool
  default     = false
}
