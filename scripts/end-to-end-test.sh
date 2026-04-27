#!/usr/bin/env bash
# Smoke-tests all three inference endpoints for a single tenant, then verifies that
# request metadata was written to DynamoDB and that the HPA is visible.
#
# Required environment variables (no defaults — the script fails fast if unset):
#   API_KEY  — x-api-key header value from `terraform output -raw tenant_a_api_key_value`
#   API_URL  — API Gateway prod stage invoke URL from `terraform output api_gateway_stage_invoke_url`
#
# Optional overrides:
#   TENANT_ID       — tenant namespace prefix; defaults to tenant-a
#   HPA_NAMESPACE   — Kubernetes namespace to query for HPA status; defaults to tenant-a
#   DYNAMODB_TABLE  — table name; defaults to ai-inference-logs
#   DYNAMODB_INDEX  — GSI name for tenant lookups; defaults to tenant-id-timestamp-index
set -euo pipefail

REGION="us-east-1"
TENANT_ID="${TENANT_ID:-tenant-a}"
TENANT_PATH="${TENANT_ID}"
HPA_NAMESPACE="${HPA_NAMESPACE:-tenant-a}"
DYNAMODB_TABLE="${DYNAMODB_TABLE:-ai-inference-logs}"
DYNAMODB_INDEX="${DYNAMODB_INDEX:-tenant-id-timestamp-index}"

# :? causes bash to abort with a descriptive error if the variable is unset or empty.
: "${API_KEY:?Set API_KEY to the tenant API key}"
: "${API_URL:?Set API_URL to the API Gateway prod stage URL}"

# Strip a trailing slash so path construction below is consistent.
API_URL="${API_URL%/}"

echo "=== Testing Summarizer ==="
curl -fsS -X POST "${API_URL}/${TENANT_PATH}/summarize" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -d '{"text": "Kubernetes is an open-source container orchestration platform that automates deployment, scaling, and management of containerized applications. It was originally designed by Google and is now maintained by the CNCF.", "max_length": 25}' \
  | python3 -m json.tool

echo ""
echo "=== Testing Generator ==="
curl -fsS -X POST "${API_URL}/${TENANT_PATH}/generate" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -d '{"text": "Write a one-paragraph product description for an AI inference platform.", "max_length": 150}' \
  | python3 -m json.tool

echo ""
echo "=== Testing Embedder ==="
curl -fsS -X POST "${API_URL}/${TENANT_PATH}/embed" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -d '{"text": "Multi-tenant AI inference platform on EKS"}' \
  | python3 -m json.tool

echo ""
echo "=== Verifying DynamoDB logs ==="
# Query the tenant-id-timestamp-index GSI to confirm all three requests were logged.
# The GSI hash key is tenant_id; --limit 5 returns the most-recent items for a quick sanity check.
aws dynamodb query \
  --region "${REGION}" \
  --table-name "${DYNAMODB_TABLE}" \
  --index-name "${DYNAMODB_INDEX}" \
  --key-condition-expression "tenant_id = :tid" \
  --expression-attribute-values "{\":tid\": {\"S\": \"${TENANT_ID}\"}}" \
  --limit 5

echo ""
echo "=== HPA Status ==="
# Confirm the HPA reports current / desired / max replicas for the summarizer deployment.
kubectl get hpa -n "${HPA_NAMESPACE}"
