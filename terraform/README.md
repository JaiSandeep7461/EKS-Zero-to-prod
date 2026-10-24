# Terraform Infrastructure Guide

This document explains the Terraform layout, the main infrastructure changes in this repository, the security decisions behind them, and the order to use the Terraform roots.

## Overview

The Terraform code is split into three independent roots so that shared setup, the EKS foundation, and the application platform can be managed separately.

| Terraform root | Purpose | Main resources |
|---|---|---|
| `bootstrap/` | Creates shared resources required by Terraform and CI/CD | S3 state bucket, DynamoDB lock table, ECR repositories, GitHub Actions OIDC provider and CI role |
| `foundation/` | Creates the network and EKS cluster | VPC, public subnets, Internet Gateway, EKS control plane, system node group, KMS key, cluster OIDC provider and EBS CSI add-on |
| `stack/` | Adds platform and application services to the existing cluster | Platform node group, namespaces, gp3 StorageClass, SonarQube EC2, Traefik, Argo CD, and observability tools |

The roots intentionally have separate state files. The stack reads the foundation's remote state rather than creating or owning the VPC and EKS control plane.

## Changes and design decisions

### 1. Bootstrap resources and remote state

Files: `bootstrap/s3_state.tf`, `bootstrap/dynamodb_lock.tf`, `bootstrap/ecr.tf`, `bootstrap/github_oidc.tf`

- Added an S3 bucket for Terraform remote state, with versioning, server-side encryption (AES-256), and S3 public access blocked.
- Enabled Terraform's S3 native lock-file mechanism in the foundation and stack backends with `use_lockfile = true`.
- Kept a pay-per-request DynamoDB lock table in bootstrap. The current foundation and stack backend blocks use S3 native lock files, not the DynamoDB locking argument.
- Added ECR repositories for `frontend`, `api-gateway`, `orders`, and `catalog`. Image tags are immutable, images are scanned on push, and a lifecycle policy retains the most recent 15 images.
- Added GitHub Actions authentication through OIDC instead of long-lived AWS access keys. The CI role trust policy is restricted to this repository, and its policies scope ECR operations to the project repositories, Terraform state access to the state bucket/lock table, and EKS permission to describe the intended cluster.
- Made the account-wide GitHub OIDC provider configurable: create it on a fresh account, or look up the existing provider when one already exists.

**Lifecycle warning:** the bootstrap root is a prerequisite for the other two roots. Its S3 bucket holds their remote state. Do not destroy bootstrap while foundation or stack state is still needed. A full teardown removes the state bucket and ECR repositories, including their contents, because the bootstrap resources explicitly allow full deletion.

### 2. EKS foundation, network, and access controls

Files: `foundation/network.tf`, `foundation/eks.tf`, `foundation/storage.tf`, `foundation/variables.tf`

- Built a fresh VPC using the configurable CIDR (default `10.20.0.0/16`) and public subnets across the selected Availability Zones.
- Added an Internet Gateway and public routing. NAT Gateways are intentionally omitted to avoid their hourly and data-processing costs in this learning environment.
- Created the `ztd-demo` EKS cluster (Kubernetes version is configurable), enabled API, audit, and authenticator control-plane logs, and enabled both private and public API endpoint access.
- Added a baseline system managed node group and an EBS CSI add-on. The EBS CSI driver uses an IAM role associated with the cluster's OIDC identity provider.
- Added a customer-managed KMS key and alias for Kubernetes Secret encryption. Automatic key rotation is enabled, and a key-use policy is attached to the EKS cluster role. The key has a seven-day deletion waiting period.
- Hardened the EKS public endpoint input: `cluster_endpoint_public_access_cidrs` is required, must not be empty, and rejects the global IPv4 CIDR `0.0.0.0/0` and IPv6 CIDR `::/0`.
- Added resource tags to make the foundation resources identifiable as Terraform-managed project infrastructure.

**Before applying:** copy `foundation/terraform.tfvars.example` to `foundation/terraform.tfvars` and set `cluster_endpoint_public_access_cidrs` to your current public IP followed by `/32`. The example IP is documentation-only. The local `terraform.tfvars` file is ignored by Git; do not commit it.

### 3. Application and platform stack

Files include `stack/nodegroup.tf`, `stack/sonarqube.tf`, `stack/ingress.tf`, `stack/argocd.tf`, `stack/observability.tf`, `stack/ci_access.tf`, and `stack/storageclass.tf`.

- Added a dedicated, separately managed platform node group so platform workloads can be scaled or destroyed independently of the foundation's system node group.
- Created application, staging, production, observability, Argo CD, and Traefik namespaces.
- Added an encrypted gp3 StorageClass for persistent workloads.
- Deployed Traefik through Helm with a public Network Load Balancer Service.
- Added Argo CD and a root “app-of-apps” resource to bootstrap GitOps from the manifests in `deploy/argocd/`.
- Added Prometheus/Grafana, Loki/Promtail, Tempo, and the OpenTelemetry Collector through pinned Helm chart versions. Grafana dashboards are loaded from the repository. The Grafana administrator password is generated by Terraform and stored in a Kubernetes Secret, not committed to Git.
- Added a SonarQube EC2 host with an encrypted gp3 root volume, IMDSv2 required, and Systems Manager Session Manager for administration instead of SSH port 22. The database password is generated if no override is provided and stored in SSM Parameter Store as a SecureString.
- Added a dedicated GitHub Actions EKS access entry with edit access limited to the `dev`, `staging`, and `prod` namespaces; this is not cluster-admin access.

### 4. Security and cost trade-offs

This is a learning/capstone configuration, not a production network template without changes.

- **No NAT Gateway:** reduces fixed networking costs, but the worker subnets are public and instances may receive public IPs. Production environments should use private worker subnets and deliberately design outbound access with NAT Gateways or suitable VPC endpoints.
- **Public EKS API:** both public and private access are enabled for this lab. Public access is constrained by the required operator CIDR allowlist. Keep the allowlist current and never use a world-open CIDR.
- **SonarQube access:** `stack/terraform.tfvars.example` currently shows `sonar_ingress_cidr = "0.0.0.0/0"` for convenience with hosted CI runners. Replace it with a trusted source CIDR where feasible before applying; port 9000 is otherwise public. The instance is configured without SSH ingress and requires IMDSv2.
- **KMS:** customer-managed key rotation and explicit EKS Secret encryption improve key control but add KMS costs. Destroying a KMS key schedules deletion after the configured seven-day waiting period rather than removing it immediately.
- The repository's documented scanner exceptions record the deliberate lab trade-offs. They do not mean the public-subnet design is production-hardened.

## Terraform state and deployment order

Run commands from Git Bash at the repository root, with AWS CLI credentials configured for the intended account. The examples use the `zero-to-prod` profile and `ap-south-1` region.

### Create or recreate the infrastructure

After a full teardown, recreate bootstrap first because the remote state bucket used by the other roots no longer exists.

```bash
export AWS_PROFILE=zero-to-prod
export AWS_REGION=ap-south-1

# 1. Shared bootstrap resources
cd terraform/bootstrap
terraform init
terraform plan
terraform apply

# 2. Network and EKS foundation
cd ../foundation
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set cluster_endpoint_public_access_cidrs
# to your current public IP with /32 before planning.
terraform init
terraform plan
terraform apply

# 3. Platform and application stack
cd ../stack
terraform init -reconfigure
terraform plan
terraform apply
```

Review every plan before applying. Do not apply the stack until the foundation cluster exists and its state is available. The local `terraform.tfvars` files contain environment-specific values and should not be committed.

### Tear down to reduce ongoing costs

Destroy in reverse dependency order, and preserve bootstrap until both remote-state roots have been destroyed successfully:

1. Destroy `terraform/stack`.
2. Destroy `terraform/foundation`.
3. Destroy `terraform/bootstrap` only when you intend to remove the state bucket, lock table, ECR repositories/images, and CI/OIDC resources too.

If bootstrap has already been destroyed, do not try to initialize the foundation or stack backend first. Restore bootstrap and its S3 state bucket before using those roots again.

## Validation

The GitHub Actions Terraform workflow checks formatting, initialization/validation, and TFLint for the Terraform roots. A successful Terraform validation confirms configuration structure; it does not mean AWS resources have been applied or that application dependency/security checks have passed.
