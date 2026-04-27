# -----------------------------------------------------------------------------
# EKS Cluster Service Role
# -----------------------------------------------------------------------------

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
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# EKS Cluster Policy Attachments
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "jabari_eks_cluster_amazon_eks_cluster" {
  role       = aws_iam_role.jabari_eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "jabari_eks_cluster_block_storage" {
  role       = aws_iam_role.jabari_eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "jabari_eks_cluster_compute" {
  role       = aws_iam_role.jabari_eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "jabari_eks_cluster_load_balancing" {
  role       = aws_iam_role.jabari_eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "jabari_eks_cluster_networking" {
  role       = aws_iam_role.jabari_eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

# -----------------------------------------------------------------------------
# EKS Worker Node Role
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# EKS Worker Node Policy Attachments
# -----------------------------------------------------------------------------

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

resource "aws_iam_role_policy_attachment" "jabari_eks_node_cloudwatch_agent" {
  role       = aws_iam_role.jabari_eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# -----------------------------------------------------------------------------
# Account and OIDC Locals
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  bedrock_inference_oidc_issuer = coalesce(
    var.bedrock_inference_oidc_issuer_url,
    aws_eks_cluster.jabari_ai_platform.identity[0].oidc[0].issuer
  )
  bedrock_inference_oidc_hostpath = replace(local.bedrock_inference_oidc_issuer, "https://", "")
}

# -----------------------------------------------------------------------------
# Bedrock Inference IRSA Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "jabari_bedrock_inference" {
  name = "jabari-bedrock-inference-role"

  depends_on = [aws_iam_openid_connect_provider.jabari_ai_platform]

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

# -----------------------------------------------------------------------------
# Bedrock Inference Inline Policy
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "jabari_bedrock_inference_inline" {
  name = "jabari-bedrock-inference-inline"
  role = aws_iam_role.jabari_bedrock_inference.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockDirectInference"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
          "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
        ]
      },
      {
        Sid    = "BedrockClaudeSonnetInferenceProfile"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:us-east-1:${data.aws_caller_identity.current.account_id}:inference-profile/us.anthropic.claude-sonnet-4-6"
      },
      {
        Sid    = "BedrockClaudeSonnetFoundationModels"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6",
          "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-6",
          "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-6"
        ]
        Condition = {
          StringLike = {
            "bedrock:InferenceProfileArn" = "arn:aws:bedrock:us-east-1:${data.aws_caller_identity.current.account_id}:inference-profile/us.anthropic.claude-sonnet-4-6"
          }
        }
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
