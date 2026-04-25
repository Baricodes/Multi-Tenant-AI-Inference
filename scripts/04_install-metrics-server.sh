#!/usr/bin/env bash
set -euo pipefail

# EKS: prefer the cluster add-on for metrics-server. If you apply this upstream
# manifest on a cluster that already uses the EKS add-on, the Service can end up
# selecting k8s-app=metrics-server while add-on pods only have app.kubernetes.io/*
# labels — Endpoints stay empty, APIService shows MissingEndpoints, and kubectl top
# / HPA see "Metrics API not available". Fix:
#   kubectl patch svc metrics-server -n kube-system --type=json \
#     -p='[{"op": "remove", "path": "/spec/selector/k8s-app"}]'

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get deployment metrics-server -n kube-system
