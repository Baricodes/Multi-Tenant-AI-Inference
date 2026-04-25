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
