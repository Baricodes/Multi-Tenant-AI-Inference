#!/usr/bin/env bash
set -euo pipefail

# Creates the IAM OIDC provider for the cluster OIDC issuer (for IRSA). Equivalent to:
#   eksctl utils associate-iam-oidc-provider --cluster ... --region ... --approve
# This repo’s Terraform (aws_iam_openid_connect_provider.jabari_ai_platform) already
# does this; only run this if you are not using that resource.

CLUSTER_NAME="jabari-ai-platform"
AWS_REGION="us-east-1"

OIDC_ISSUER=$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query "cluster.identity.oidc.issuer" \
  --output text)

if [[ -z "${OIDC_ISSUER}" || "${OIDC_ISSUER}" == "None" ]]; then
  echo "Error: cluster has no OIDC issuer." >&2
  exit 1
fi

OIDC_HOSTPATH="${OIDC_ISSUER#https://}"
OIDC_HOST="${OIDC_HOSTPATH%%/*}"

echo "OIDC issuer: ${OIDC_ISSUER}"
echo "Fetching SHA-1 thumbprint for ${OIDC_HOST}:443 (openssl) ..."

THUMBPRINT=$(
  echo | openssl s_client -servername "${OIDC_HOST}" -connect "${OIDC_HOST}:443" 2>/dev/null \
    | openssl x509 -fingerprint -noout -sha1 2>/dev/null \
    | sed 's/^.*=//' | tr -d ':\n'
)

if [[ -z "${THUMBPRINT}" ]]; then
  echo "Error: could not read TLS certificate thumbprint (is openssl installed?)" >&2
  exit 1
fi

set +e
ERR=$(aws iam create-open-id-connect-provider \
  --url "${OIDC_ISSUER}" \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list "${THUMBPRINT}" 2>&1)
RC=$?
set -e

if [[ ${RC} -eq 0 ]]; then
  echo "Created IAM OIDC identity provider for ${OIDC_ISSUER}"
  exit 0
fi
if echo "${ERR}" | grep -q 'EntityAlreadyExists'; then
  echo "IAM OIDC provider for this URL already exists (nothing to do)."
  exit 0
fi
echo "${ERR}" >&2
exit "${RC}"
