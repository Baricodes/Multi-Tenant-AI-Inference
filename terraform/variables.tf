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
  description = "EKS OIDC issuer URL for IRSA (output of: aws eks describe-cluster --query cluster.identity.oidc.issuer). Used as jabari-bedrock-inference-role trust (AssumeRoleWithWebIdentity)."
  type        = string
}
