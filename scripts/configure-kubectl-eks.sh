#!/usr/bin/env bash
set -euo pipefail

# Configure kubectl for your EKS cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name jabari-ai-platform

# Verify connection
kubectl get nodes

# Verify namespaces
kubectl get namespaces