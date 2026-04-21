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
