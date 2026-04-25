output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ)."
  value       = aws_subnet.private[*].id
}

output "platform_nlb_arn" {
  description = "ARN of the internal network load balancer (same subnets as the Ingress internal ALB)."
  value       = aws_lb.platform_nlb.arn
}

output "platform_nlb_dns_name" {
  description = "DNS name of the internal network load balancer."
  value       = aws_lb.platform_nlb.dns_name
}

output "platform_nlb_target_group_arn" {
  description = "ARN of the NLB TCP :80 target group (target type ALB → internal Ingress ALB)."
  value       = aws_lb_target_group.platform_nlb_tcp.arn
}

output "platform_nlb_target_group_name" {
  description = "Final name of the NLB target group in AWS (includes random suffix when using name_prefix)."
  value       = aws_lb_target_group.platform_nlb_tcp.name
}

output "platform_ingress_alb_arn" {
  description = "ARN of the internal ALB attached to the NLB target group; null if attach_platform_ingress_alb_to_nlb is false."
  value       = local.platform_ingress_alb_arn
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs (one per AZ)."
  value       = aws_nat_gateway.main[*].id
}

output "availability_zones" {
  description = "AZs used for subnets."
  value       = local.azs
}

output "bedrock_runtime_vpc_endpoint_id" {
  description = "Interface VPC endpoint ID for Bedrock Runtime (private DNS enabled)."
  value       = aws_vpc_endpoint.bedrock_runtime.id
}

output "ecr_repository_urls" {
  description = "ECR repository URLs for tenant service images (keys match repository name)."
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs for IAM policies and references."
  value       = { for k, r in aws_ecr_repository.service : k => r.arn }
}

output "jabari_eks_cluster_role_arn" {
  description = "IAM role ARN for the EKS cluster service role (jabari-eks-cluster-role)."
  value       = aws_iam_role.jabari_eks_cluster.arn
}

output "jabari_eks_node_role_arn" {
  description = "IAM role ARN for EKS worker nodes (jabari-eks-node-role)."
  value       = aws_iam_role.jabari_eks_node.arn
}

output "jabari_bedrock_inference_role_arn" {
  description = "IAM role ARN for Bedrock inference workloads (jabari-bedrock-inference-role)."
  value       = aws_iam_role.jabari_bedrock_inference.arn
}

output "jabari_ai_platform_cluster_name" {
  description = "EKS control plane name (jabari-ai-platform)."
  value       = aws_eks_cluster.jabari_ai_platform.name
}

output "jabari_ai_platform_cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.jabari_ai_platform.arn
}

output "jabari_ai_platform_cluster_endpoint" {
  description = "Kubernetes API server endpoint for kubectl."
  value       = aws_eks_cluster.jabari_ai_platform.endpoint
}

output "jabari_ai_platform_cluster_version" {
  description = "Kubernetes server version running on the control plane."
  value       = aws_eks_cluster.jabari_ai_platform.version
}

output "jabari_ai_platform_cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA (same as cluster identity)."
  value       = aws_eks_cluster.jabari_ai_platform.identity[0].oidc[0].issuer
}

output "jabari_ai_platform_oidc_provider_arn" {
  description = "IAM OIDC identity provider ARN for the cluster (IRSA)."
  value       = aws_iam_openid_connect_provider.jabari_ai_platform.arn
}
