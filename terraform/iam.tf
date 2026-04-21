# EKS cluster service role (console use case: EKS → EKS - Cluster).
resource "aws_iam_role" "jabari_eks_cluster" {
  name = "jabari-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jabari_eks_cluster_amazon_eks_cluster" {
  role       = aws_iam_role.jabari_eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS managed node group / worker role (trusted by EC2).
resource "aws_iam_role" "jabari_eks_node" {
  name = "jabari-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jabari_eks_node_worker" {
  role       = aws_iam_role.jabari_eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "jabari_eks_node_cni" {
  role       = aws_iam_role.jabari_eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "jabari_eks_node_ecr_readonly" {
  role       = aws_iam_role.jabari_eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

data "aws_caller_identity" "current" {}

locals {
  bedrock_inference_oidc_hostpath = replace(var.bedrock_inference_oidc_issuer_url, "https://", "")
}

# Application / inference role (IRSA: EKS service accounts tenant-* / bedrock-sa).
resource "aws_iam_role" "jabari_bedrock_inference" {
  name = "jabari-bedrock-inference-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.bedrock_inference_oidc_hostpath}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "${local.bedrock_inference_oidc_hostpath}:sub" = "system:serviceaccount:tenant-*:bedrock-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "jabari_bedrock_inference_inline" {
  name = "jabari-bedrock-inference-inline"
  role = aws_iam_role.jabari_bedrock_inference.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInference"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
          "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
        ]
      },
      {
        Sid    = "DynamoDBLogging"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:*:table/ai-inference-logs"
      }
    ]
  })
}
