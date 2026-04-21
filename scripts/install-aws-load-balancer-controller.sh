#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
CLUSTER_NAME="jabari-ai-platform"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Add IAM policy for the LBC
curl -fsSL -o "$TMP/iam_policy.json" \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document "file://${TMP}/iam_policy.json"

# Create a service account for the controller
eksctl create iamserviceaccount \
  --cluster="${CLUSTER_NAME}" \
  --region="${REGION}" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn="${POLICY_ARN}" \
  --approve

# Install the controller via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
