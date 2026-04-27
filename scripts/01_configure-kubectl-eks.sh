#!/usr/bin/env bash
# Writes an EKS cluster entry to ~/.kube/config so kubectl commands target the right cluster.
# Run this first after `terraform apply` provisions the cluster and before any subsequent scripts.
set -euo pipefail

# update-kubeconfig merges the cluster CA, endpoint, and aws-iam-authenticator token command
# into the active kubeconfig context. Subsequent kubectl calls authenticate via IAM.
aws eks update-kubeconfig \
  --region us-east-1 \
  --name jabari-ai-platform

# Verify the connection and confirm nodes are in Ready state before proceeding.
kubectl get nodes
