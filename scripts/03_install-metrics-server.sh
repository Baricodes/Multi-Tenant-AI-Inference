#!/usr/bin/env bash
# Installs the Kubernetes Metrics Server, which the HPA relies on to read CPU / memory
# utilization from pods. Without it, `kubectl top` and HPA scaling both fail.

# EKS: prefer the cluster add-on for metrics-server. If you apply this upstream
# manifest on a cluster that already uses the EKS add-on, the Service can end up
# selecting k8s-app=metrics-server while add-on pods only have app.kubernetes.io/*
# labels — Endpoints stay empty, APIService shows MissingEndpoints, and kubectl top /
# HPA see "Metrics API not available". Fix:
#   kubectl patch svc metrics-server -n kube-system --type=json \
#     -p='[{"op": "remove", "path": "/spec/selector/k8s-app"}]'

set -euo pipefail

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify the Deployment is present; use `kubectl rollout status` to wait for it to be Ready.
kubectl get deployment metrics-server -n kube-system
