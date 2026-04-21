#!/usr/bin/env bash
set -euo pipefail

# Get the OIDC provider URL from the EKS cluster
OIDC_URL=$(aws eks describe-cluster \
  --name jabari-ai-platform \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text | sed 's|https://||')

echo "OIDC issuer (without https://): ${OIDC_URL}"

# Create the OIDC provider in IAM
eksctl utils associate-iam-oidc-provider \
  --cluster jabari-ai-platform \
  --region us-east-1 \
  --approve
