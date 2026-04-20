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
