# Multi-Tenant AI Inference Platform

**Status: in progress.** This repository is under active development. The architecture and implementation are evolving; not all planned components exist in the tree yet.

## What I am building

A multi-tenant AI inference platform on Amazon EKS that:

- Runs **multiple AI models** as separate containerized services, backed by **Amazon Bedrock** microservice-style integrations.
- Uses an **API Gateway** (or equivalent routing layer) so clients hit one entry point; **routing** sends traffic to the right model based on **task type** (or similar request metadata).
- Adds **Horizontal Pod Autoscaler (HPA)** behavior that can scale workloads using **signals aligned with request queue depth** (or comparable queue/backpressure metrics), so capacity follows real demand.
- Gives **each tenant an isolated Kubernetes namespace** with **RBAC** tuned so tenants stay logically separated at the cluster level.

The goal is a stack that mirrors what many teams run for **internal AI platforms**: Bedrock for model access, Kubernetes for orchestration, clear tenancy boundaries, and autoscaling tied to how backed up inference work actually is.

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
