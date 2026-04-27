#!/usr/bin/env bash
set -euo pipefail

# Run after the API Gateway deployment is available.
# Example:
# API_KEY="<tenant-a-api-key>" \
# API_URL="https://<api-id>.execute-api.us-east-1.amazonaws.com/prod" \

REGION="us-east-1"
TENANT_ID="${TENANT_ID:-tenant-a}"
DYNAMODB_TABLE="${DYNAMODB_TABLE:-ai-inference-logs}"
DYNAMODB_INDEX="${DYNAMODB_INDEX:-tenant-id-timestamp-index}"

: "${API_KEY:?Set API_KEY to the tenant API key}"
: "${API_URL:?Set API_URL to the API Gateway prod stage URL}"

API_URL="${API_URL%/}"

echo "=== Testing Summarizer ==="
curl -fsS -X POST "${API_URL}/summarize" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -H "x-tenant-id: ${TENANT_ID}" \
  -d '{"text": "Kubernetes is an open-source container orchestration platform that automates deployment, scaling, and management of containerized applications. It was originally designed by Google and is now maintained by the CNCF.", "max_length": 25}' \
  | python3 -m json.tool

echo ""
echo "=== Testing Generator ==="
curl -fsS -X POST "${API_URL}/generate" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -H "x-tenant-id: ${TENANT_ID}" \
  -d '{"text": "Write a one-paragraph product description for an AI inference platform.", "max_length": 150}' \
  | python3 -m json.tool

echo ""
echo "=== Testing Embedder ==="
curl -fsS -X POST "${API_URL}/embed" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -H "x-tenant-id: ${TENANT_ID}" \
  -d '{"text": "Multi-tenant AI inference platform on EKS"}' \
  | python3 -m json.tool

echo ""
echo "=== Verifying DynamoDB logs ==="
aws dynamodb query \
  --region "${REGION}" \
  --table-name "${DYNAMODB_TABLE}" \
  --index-name "${DYNAMODB_INDEX}" \
  --key-condition-expression "tenant_id = :tid" \
  --expression-attribute-values "{\":tid\": {\"S\": \"${TENANT_ID}\"}}" \
  --limit 5

echo ""
echo "=== HPA Status ==="
kubectl get hpa -n "${TENANT_ID}"
