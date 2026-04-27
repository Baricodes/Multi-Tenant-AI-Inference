#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text --region us-east-1)}"

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
# its ARN via the ELBv2 API, then let Terraform own the attachment so the
# state stays consistent with the rest of the infrastructure.  By default this
# script prints the Terraform command instead of applying it; set
# APPLY_NLB_ATTACHMENT=true to run it from here.
# ---------------------------------------------------------------------------
TERRAFORM_DIR="$ROOT/terraform"
INGRESS_NAME="tenant-a-ingress"
INGRESS_NS="tenant-a"
REGION="us-east-1"
WAIT_ATTEMPTS=36   # 36 × 10 s = 6 minutes
WAIT_INTERVAL=10
APPLY_NLB_ATTACHMENT="${APPLY_NLB_ATTACHMENT:-false}"

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
  echo "    terraform -chdir=$TERRAFORM_DIR apply \\" >&2
  echo "      -var=\"attach_platform_ingress_alb_to_nlb=true\" \\" >&2
  echo "      -var=\"platform_ingress_alb_arn=\$ALB_ARN\"" >&2
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
if [[ "$APPLY_NLB_ATTACHMENT" == "true" ]]; then
  echo "Attaching internal ALB to NLB target group via Terraform..."
  terraform -chdir="$TERRAFORM_DIR" apply \
    -var="attach_platform_ingress_alb_to_nlb=true" \
    -var="platform_ingress_alb_arn=${ALB_ARN}"
else
  echo "Terraform attachment not applied automatically."
  echo "Review and run this command when you are ready to attach the ALB to the NLB target group:"
  echo ""
  echo "  terraform -chdir=$TERRAFORM_DIR apply \\"
  echo "    -var=\"attach_platform_ingress_alb_to_nlb=true\" \\"
  echo "    -var=\"platform_ingress_alb_arn=${ALB_ARN}\""
fi

echo ""
if [[ "$APPLY_NLB_ATTACHMENT" == "true" ]]; then
  echo "NLB target group is now wired to the internal ALB."
  echo "API Gateway VPC Link → NLB → ALB → tenant services."
else
  echo "API Gateway VPC Link traffic will reach tenant services after the Terraform attachment is applied."
fi
echo ""
echo "To make the attachment permanent across future 'terraform apply' runs, add"
echo "the following to terraform/terraform.tfvars (create the file if it does not exist):"
echo ""
echo "  attach_platform_ingress_alb_to_nlb = true"
echo "  platform_ingress_alb_arn           = \"${ALB_ARN}\""
