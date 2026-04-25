# Multi-Tenant AI Inference Platform

**Status: in progress.** This repository is under active development. The architecture and implementation are evolving; not all planned components exist in the tree yet.

## What I am building

A multi-tenant AI inference platform on Amazon EKS that:

- Runs **multiple AI models** as separate containerized services, backed by **Amazon Bedrock** microservice-style integrations.
- Uses an **API Gateway** (or equivalent routing layer) so clients hit one entry point; **routing** sends traffic to the right model based on **task type** (or similar request metadata).
- Adds **Horizontal Pod Autoscaler (HPA)** behavior that can scale workloads using **signals aligned with request queue depth** (or comparable queue/backpressure metrics), so capacity follows real demand.
- Gives **each tenant an isolated Kubernetes namespace** with **RBAC** tuned so tenants stay logically separated at the cluster level.

The goal is a stack that mirrors what many teams run for **internal AI platforms**: Bedrock for model access, Kubernetes for orchestration, clear tenancy boundaries, and autoscaling tied to how backed up inference work actually is.

## Prerequisites

| Tool | Used for | Install |
| --- | --- | --- |
| [Helm](https://helm.sh/) 3+ | [AWS Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller) install (`scripts/03_install-aws-load-balancer-controller.sh`) | [Official install guide](https://helm.sh/docs/intro/install/). On macOS with Homebrew: `brew install helm` |
| [AWS CLI](https://aws.amazon.com/cli/) v2 | Terraform, `kubectl` setup, helper scripts | [Installing the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| [Terraform](https://www.terraform.io/) | Infrastructure under `terraform/` (see `terraform/versions.tf` for the required version) | [Install Terraform](https://developer.hashicorp.com/terraform/install) |
| [kubectl](https://kubernetes.io/docs/reference/kubectl/) | Apply manifests, Helm, cluster inspection | [Install kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) (often with `aws eks update-kubeconfig` and the AWS CLI) |

You also need **network access** to pull Helm charts, and (for the LBC install script) `curl` in your PATH. Other scripts use **OpenSSL** (for example `scripts/02_eks-associate-oidc-provider.sh`).

`eksctl` is **not** required; helper scripts use the AWS CLI and `kubectl` instead.

## Current state of this repo

Today the codebase focuses on **AWS networking and private Bedrock connectivity**:

- Terraform provisions a **VPC** with public and private subnets across two Availability Zones, NAT gateways, and routing.
- A **VPC interface endpoint for Bedrock Runtime** (private DNS) is configured so workloads in the VPC can call Bedrock without traversing the public internet.

EKS, API Gateway wiring, per-tenant namespaces/RBAC, and HPA manifests are **planned** as this project continues; they are not fully represented here yet.

## Terraform

Infrastructure lives under `terraform/`. Typical workflow:

```bash
cd terraform
terraform init
terraform plan
```

Configure `aws_region` and `name_prefix` via `variables.tf` or `-var` flags as needed. The default region is `us-east-1`.
