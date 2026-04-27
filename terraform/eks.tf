# -----------------------------------------------------------------------------
# EKS Control Plane
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "jabari_ai_platform" {
  name     = "jabari-ai-platform"
  role_arn = aws_iam_role.jabari_eks_cluster.arn

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.jabari_eks_cluster_amazon_eks_cluster,
    aws_iam_role_policy_attachment.jabari_eks_cluster_block_storage,
    aws_iam_role_policy_attachment.jabari_eks_cluster_compute,
    aws_iam_role_policy_attachment.jabari_eks_cluster_load_balancing,
    aws_iam_role_policy_attachment.jabari_eks_cluster_networking,
  ]

  tags = {
    Name = "jabari-ai-platform"
  }
}

# -----------------------------------------------------------------------------
# EKS Managed Node Group
# -----------------------------------------------------------------------------

resource "aws_eks_node_group" "jabari_ai_nodes" {
  cluster_name    = aws_eks_cluster.jabari_ai_platform.name
  node_group_name = "jabari-ai-nodes"
  node_role_arn   = aws_iam_role.jabari_eks_node.arn
  subnet_ids      = aws_subnet.private[*].id

  capacity_type  = "ON_DEMAND"
  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.medium"]
  disk_size      = 20

  scaling_config {
    desired_size = 3
    max_size     = 10
    min_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.jabari_eks_node_cni,
    aws_iam_role_policy_attachment.jabari_eks_node_ecr_readonly,
    aws_iam_role_policy_attachment.jabari_eks_node_worker,
  ]

  tags = {
    Name = "jabari-ai-nodes"
  }
}

# -----------------------------------------------------------------------------
# Cluster OIDC Provider for IRSA
# -----------------------------------------------------------------------------

data "tls_certificate" "jabari_ai_platform_eks_oidc" {
  url = aws_eks_cluster.jabari_ai_platform.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "jabari_ai_platform" {
  client_id_list = ["sts.amazonaws.com"]
  url            = aws_eks_cluster.jabari_ai_platform.identity[0].oidc[0].issuer
  thumbprint_list = distinct(
    data.tls_certificate.jabari_ai_platform_eks_oidc.certificates[*].sha1_fingerprint
  )

  tags = {
    Name = "jabari-ai-platform-eks-oidc"
  }
}
