#!/usr/bin/env bash
# Applies all Kubernetes manifests via Kustomize and then wires the LBC-managed internal ALB
# to the NLB target group so API Gateway VPC Link traffic reaches the tenant services.
# Run after scripts 01–05 (kubectl configured, LBC installed, images in ECR).
set -euo pipefail

# Resolve the repo root regardless of where the script is invoked from.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text --region us-east-1)}"

# Kustomize renders the manifest set and sed substitutes the account ID placeholder used
# in ECR image URIs before piping the result directly to kubectl apply.
kubectl kustomize "$ROOT/k8s" | sed "s/__AWS_ACCOUNT_ID__/${ACCOUNT_ID}/g" | kubectl apply -f -

echo ""
echo "Pods (tenant-a, tenant-b):"
kubectl get pods -n tenant-a
kubectl get pods -n tenant-b

echo ""
echo "HPA (tenant-a):"
kubectl get hpa -n tenant-a

echo ""
echo "Ingress (ALB DNS may take a few minutes):"
kubectl get ingress -n tenant-a

# ---------------------------------------------------------------------------
# Wire the LBC-managed internal ALB to the NLB target group so API Gateway
# VPC Link traffic actually reaches the tenant services.
#
# The AWS Load Balancer Controller creates the ALB asynchronously after the
# Ingress is applied.  We poll until the Ingress reports a hostname, resolve
# its ARN via the ELBv2 API, then register that ALB with the Terraform-created
# NLB target group. The ALB ARN is discovered at runtime so demo deployments do
# not need hardcoded or committed environment-specific values.
# ---------------------------------------------------------------------------
TERRAFORM_DIR="$ROOT/terraform"
INGRESS_NAME="tenant-a-ingress"
INGRESS_NS="tenant-a"
REGION="us-east-1"
WAIT_ATTEMPTS=36   # 36 × 10 s = 6 minutes
WAIT_INTERVAL=10
REGISTER_NLB_TARGET="${REGISTER_NLB_TARGET:-${APPLY_NLB_ATTACHMENT:-true}}"

echo ""
echo "Waiting for Ingress ALB to be provisioned (up to ~6 minutes)..."
ALB_HOSTNAME=""
for i in $(seq 1 "$WAIT_ATTEMPTS"); do
  ALB_HOSTNAME=$(
    kubectl get ingress "$INGRESS_NAME" -n "$INGRESS_NS" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
  )
  if [[ -n "$ALB_HOSTNAME" && "$ALB_HOSTNAME" != "None" ]]; then
    echo "Ingress ALB hostname: $ALB_HOSTNAME"
    break
  fi
  echo "  ($i/$WAIT_ATTEMPTS) hostname not yet assigned – retrying in ${WAIT_INTERVAL}s..."
  sleep "$WAIT_INTERVAL"
done

if [[ -z "$ALB_HOSTNAME" || "$ALB_HOSTNAME" == "None" ]]; then
  echo ""
  echo "WARNING: Ingress ALB hostname was not assigned within the wait window." >&2
  echo "  The NLB target group is still empty; API Gateway requests will be dropped." >&2
  echo "  Once the ALB is ready, wire it manually:" >&2
  echo ""
  echo "    ALB_ARN=\$(aws elbv2 describe-load-balancers \\" >&2
  echo "      --query \"LoadBalancers[?DNSName=='\$(kubectl get ingress $INGRESS_NAME -n $INGRESS_NS -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')'].LoadBalancerArn | [0]\" \\" >&2
  echo "      --output text --region $REGION)" >&2
  echo "    TG_ARN=\$(terraform -chdir=$TERRAFORM_DIR output -raw platform_nlb_target_group_arn)" >&2
  echo "    aws elbv2 register-targets --region $REGION \\" >&2
  echo "      --target-group-arn \"\$TG_ARN\" \\" >&2
  echo "      --targets Id=\"\$ALB_ARN\",Port=80" >&2
  echo ""
  exit 0
fi

# Resolve the hostname to an ALB ARN via the ELBv2 API.  The DNS name
# returned by ELBv2 is the canonical form; strip any trailing dot that
# kubectl may include.
ALB_HOSTNAME="${ALB_HOSTNAME%.}"
ALB_ARN=$(
  aws elbv2 describe-load-balancers \
    --region "$REGION" \
    --query "LoadBalancers[?DNSName=='${ALB_HOSTNAME}'].LoadBalancerArn | [0]" \
    --output text
)

if [[ -z "$ALB_ARN" || "$ALB_ARN" == "None" ]]; then
  echo ""
  echo "WARNING: Could not resolve ALB ARN for hostname '$ALB_HOSTNAME'." >&2
  echo "  Check that your AWS credentials have elbv2:DescribeLoadBalancers permission." >&2
  exit 0
fi

echo "Internal ALB ARN: $ALB_ARN"
echo ""
TG_ARN="$(terraform -chdir="$TERRAFORM_DIR" output -raw platform_nlb_target_group_arn)"
echo "NLB target group ARN: $TG_ARN"
echo ""
if [[ "$REGISTER_NLB_TARGET" == "true" ]]; then
  echo "Registering internal ALB with NLB target group..."
  aws elbv2 register-targets \
    --region "$REGION" \
    --target-group-arn "$TG_ARN" \
    --targets "Id=${ALB_ARN},Port=80"

  echo "Waiting for NLB target health to become healthy (up to ~3 minutes)..."
  TARGET_HEALTH=""
  for i in $(seq 1 18); do
    TARGET_HEALTH=$(
      aws elbv2 describe-target-health \
        --region "$REGION" \
        --target-group-arn "$TG_ARN" \
        --targets "Id=${ALB_ARN},Port=80" \
        --query "TargetHealthDescriptions[0].TargetHealth.State" \
        --output text 2>/dev/null || true
    )
    if [[ "$TARGET_HEALTH" == "healthy" ]]; then
      echo "NLB target health: healthy"
      break
    fi
    echo "  ($i/18) target health is '${TARGET_HEALTH:-unknown}' – retrying in 10s..."
    sleep 10
  done

  if [[ "$TARGET_HEALTH" != "healthy" ]]; then
    echo "WARNING: NLB target did not become healthy within the wait window." >&2
    echo "  Current target health: ${TARGET_HEALTH:-unknown}" >&2
    echo "  Check target health in EC2 or rerun this script after the ALB is ready." >&2
  fi
else
  echo "NLB target registration not applied automatically."
  echo "Review and run this command when you are ready to register the ALB with the NLB target group:"
  echo ""
  echo "  aws elbv2 register-targets --region $REGION \\"
  echo "    --target-group-arn \"$TG_ARN\" \\"
  echo "    --targets Id=\"${ALB_ARN}\",Port=80"
fi

echo ""
if [[ "$REGISTER_NLB_TARGET" == "true" ]]; then
  echo "NLB target group is now wired to the internal ALB."
  echo "API Gateway VPC Link → NLB → ALB → tenant services."
else
  echo "API Gateway VPC Link traffic will reach tenant services after the NLB target is registered."
fi
