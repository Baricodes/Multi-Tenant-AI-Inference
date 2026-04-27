#!/usr/bin/env bash
set -euo pipefail

# Applies the AWS Container Insights quickstart (CloudWatch agent + Fluent Bit DaemonSet).
# Requires kubectl configured for the target EKS cluster and IAM permissions for the
# node/instance role to publish metrics and logs to CloudWatch.

ClusterName=jabari-ai-platform
RegionName=us-east-1
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'

# ConfigMap.data values must be strings. Bare 2020 unmarshals as a number; bare Off/On can
# become YAML booleans — both make kubectl reject fluent-bit-cluster-info, which then breaks
# Fluent Bit pods (envFrom) with CreateContainerConfigError.
curl -fsSL https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml \
  | sed \
    -e 's/{{cluster_name}}/'"${ClusterName//\//\\/}"'/g' \
    -e 's/{{region_name}}/'"${RegionName//\//\\/}"'/g' \
    -e 's/{{http_server_toggle}}/"On"/g' \
    -e 's/{{http_server_port}}/"'"${FluentBitHttpPort}"'"/g' \
    -e 's/{{read_from_head}}/"'"${FluentBitReadFromHead}"'"/g' \
    -e 's/{{read_from_tail}}/"On"/g' \
  | kubectl apply -f -

# Container Insights still reads EC2 metadata for node identity. With the usual IMDSv2
# hop limit, pods cannot reach IMDS unless the agent uses the host network namespace.
kubectl patch daemonset/cloudwatch-agent \
  -n amazon-cloudwatch \
  --type='strategic' \
  -p '{"spec":{"template":{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}}}'

# The quickstart ClusterRole omits a few resources that the current agent attempts to
# list. Reconcile only the missing permissions so upstream quickstart rules remain intact.
kubectl auth reconcile -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cloudwatch-agent-role
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes", "persistentvolumeclaims"]
    verbs: ["list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch"]
EOF
