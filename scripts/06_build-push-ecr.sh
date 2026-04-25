#!/usr/bin/env bash
set -euo pipefail

# Run from the repository root.
# Override account: AWS_ACCOUNT_ID=123456789012 ./scripts/06_build-push-ecr.sh
# Override tag:       IMAGE_TAG=v1 ./scripts/06_build-push-ecr.sh

# Must match terraform/ecr.tf locals.ecr_repository_names (path after registry host).
AWS_REGION="us-east-1"
ECR_REPOSITORY_PREFIX="jabari"
IMAGE_TAG="${IMAGE_TAG:-latest}"

ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text --region "${AWS_REGION}")}"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Order matches terraform/ecr.tf: jabari/<slug>-service
SERVICES=(summarizer generator embedder)
SERVICE_CONTEXTS=(summarizer-service generator-service embedder-service)

# Authenticate Docker to ECR
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS \
  --password-stdin "${REGISTRY}"

for i in "${!SERVICES[@]}"; do
  SERVICE="${SERVICES[$i]}"
  CONTEXT="./${SERVICE_CONTEXTS[$i]}"
  if [[ ! -d "${CONTEXT}" ]]; then
    echo "Skipping ${SERVICE}: no directory ${CONTEXT} (add it when ready)" >&2
    continue
  fi

  REPO_IMAGE="${ECR_REPOSITORY_PREFIX}/${SERVICE}-service"

  docker build --provenance=false \
    -t "${REPO_IMAGE}:${IMAGE_TAG}" \
    "${CONTEXT}"

  docker tag "${REPO_IMAGE}:${IMAGE_TAG}" \
    "${REGISTRY}/${REPO_IMAGE}:${IMAGE_TAG}"

  docker push "${REGISTRY}/${REPO_IMAGE}:${IMAGE_TAG}"
done
