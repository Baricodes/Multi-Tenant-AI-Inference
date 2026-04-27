#!/usr/bin/env bash
# Builds each service image and pushes it to ECR.
# Run from the repository root.
# Override account: AWS_ACCOUNT_ID=123456789012 ./scripts/05_build-push-ecr.sh
# Override tag:       IMAGE_TAG=v1 ./scripts/05_build-push-ecr.sh
set -euo pipefail

# Must match terraform/ecr.tf locals.ecr_repository_names (path after registry host).
REGION="us-east-1"
ECR_REPOSITORY_PREFIX="jabari"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Fall back to a live STS call if the caller has not pre-exported AWS_ACCOUNT_ID.
ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text --region "${REGION}")}"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# SERVICES and SERVICE_CONTEXTS are parallel arrays: SERVICES[i] is the ECR repo slug
# and SERVICE_CONTEXTS[i] is the local build-context directory for that service.
# Order matches terraform/ecr.tf: jabari/<slug>-service
SERVICES=(summarizer generator embedder)
SERVICE_CONTEXTS=(summarizer-service generator-service embedder-service)

# Exchange a short-lived ECR password for a Docker credential before the loop
# so the token is not re-fetched per image (tokens are valid for 12 hours).
aws ecr get-login-password --region "${REGION}" | \
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

  # --provenance=false suppresses the BuildKit provenance attestation manifest that
  # Docker adds by default; ECR and some AWS tooling reject multi-platform index manifests.
  docker build --provenance=false \
    -t "${REPO_IMAGE}:${IMAGE_TAG}" \
    "${CONTEXT}"

  # Tag with the full registry hostname before pushing so Docker routes to the correct ECR endpoint.
  docker tag "${REPO_IMAGE}:${IMAGE_TAG}" \
    "${REGISTRY}/${REPO_IMAGE}:${IMAGE_TAG}"

  docker push "${REGISTRY}/${REPO_IMAGE}:${IMAGE_TAG}"
done
