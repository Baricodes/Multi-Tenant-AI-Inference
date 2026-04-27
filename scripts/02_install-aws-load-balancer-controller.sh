#!/usr/bin/env bash
# Installs the AWS Load Balancer Controller into kube-system via Helm.
# The controller watches Ingress objects and provisions ALBs / TargetGroups automatically.
# Prerequisites: kubectl configured for jabari-ai-platform, Helm 3+, and OIDC enabled on the cluster.
set -euo pipefail

if ! command -v helm &>/dev/null; then
  echo "Error: helm is not installed. Install Helm 3+ (see README prerequisites), e.g. on macOS: brew install helm" >&2
  echo "  https://helm.sh/docs/intro/install/" >&2
  exit 1
fi

REGION="us-east-1"
CLUSTER_NAME="jabari-ai-platform"
# All generated files (IAM policy JSON, trust policy, ServiceAccount YAML) go into a
# temporary directory that is cleaned up automatically when the script exits.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Add IAM policy for the LBC
# Keep this version aligned with the installed Helm chart (2.16+ includes permissions required by 3.x controllers).
curl -fsSL -o "$TMP/iam_policy.json" \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.16.0/docs/install/iam_policy.json

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"

if ! aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
  aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document "file://${TMP}/iam_policy.json"
else
  echo "IAM policy ${POLICY_ARN} already exists" >&2
fi

# IRSA: same as `eksctl create iamserviceaccount ...` (no eksctl required).
OIDC_ISSUER=$(
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query "cluster.identity.oidc.issuer" --output text
)
VPC_ID=$(
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query "cluster.resourcesVpcConfig.vpcId" --output text
)
if [[ -z "$OIDC_ISSUER" || "$OIDC_ISSUER" == "None" ]]; then
  echo "Error: cluster has no OIDC issuer; enable IRSA for the cluster first." >&2
  exit 1
fi

# Strip the https:// scheme to get the bare host path used in IAM OIDC provider ARNs and trust conditions.
OIDC_HOSTPATH="${OIDC_ISSUER#https://}"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_HOSTPATH}"
ROLE_NAME="AmazonEKSLoadBalancerControllerRole"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

TRUST_FILE="${TMP}/lbc-trust.json"
cat > "$TRUST_FILE" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_HOSTPATH}:aud": "sts.amazonaws.com",
          "${OIDC_HOSTPATH}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
JSON

if ! aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://${TRUST_FILE}" \
    --description "IRSA for AWS Load Balancer Controller (EKS ${CLUSTER_NAME})"
else
  echo "IAM role ${ROLE_NAME} already exists; updating trust policy for current cluster OIDC issuer" >&2
  aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document "file://${TRUST_FILE}"
fi

# attach-role-policy is idempotent: running it again on an already-attached policy is a no-op.
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"

SA_FILE="${TMP}/aws-lbc-sa.yaml"
cat > "$SA_FILE" <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}
YAML
kubectl apply -f "$SA_FILE"

# Install the controller via Helm
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update
# Pass region and VPC ID so the controller does not rely on EC2 instance metadata (IMDS),
# which often times out from pods (hop limit / network path). See LBC logs:
# "failed to get VPC ID: failed to fetch VPC ID from instance metadata"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
