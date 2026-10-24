# Fresh-account deployment runbook

This runbook describes a fresh deployment into the AWS account configured by this repository. It is split into Terraform roots because the stack's Kubernetes and Helm providers need a real, already-created EKS API endpoint during planning.

## Prerequisites

- Terraform 1.10 or newer.
- AWS CLI configured with the `zero-to-prod` profile and permissions to create EKS, IAM, VPC, EC2, KMS, S3, ECR, and related resources.
- kubectl installed locally. Argo CD bootstrap uses AWS CLI and kubectl.
- Bootstrap completed successfully. Its state bucket and ECR repositories are persistent resources.

Use Git Bash from the repository root:

```bash
export AWS_PROFILE=zero-to-prod
export AWS_REGION=ap-south-1
```

## 1. Bootstrap (already completed in this account)

For a brand-new account, run:

```bash
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
```

This creates the state bucket, DynamoDB lock table retained from the bootstrap layer, four ECR repositories, GitHub Actions OIDC provider, and CI role. Do not run `terraform destroy` here while other roots still use the bucket/ECR.

## 2. Create the foundation

The cluster API endpoint must not be left open to the world. Before planning, create a local variables file and set the public API allowlist to your current public IP with `/32`. The file is ignored by Git:

```bash
cd ../foundation
cp terraform.tfvars.example terraform.tfvars
curl -4 https://checkip.amazonaws.com
```

Edit `terraform.tfvars` and replace the documentation-only value for `cluster_endpoint_public_access_cidrs` with your public IP followed by `/32`, for example `["YOUR.PUBLIC.IP/32"]`. Do not commit `terraform.tfvars`, and do not use `0.0.0.0/0`.

Then run:

```bash
terraform init
terraform plan
```

Review the plan. It creates:
- A new VPC (`10.20.0.0/16` by default), public subnets across three Availability Zones, Internet Gateway, and routes.
- The `ztd-demo` EKS control plane (Kubernetes 1.36 by default).
- A customer-managed KMS key with rotation enabled for Kubernetes Secrets encryption.
- A small baseline managed node group for system components.
- The cluster OIDC provider and EBS CSI add-on with its IAM role.

Then run:

```bash
terraform apply
```

**Security/cost trade-off for this learning stack:** the public EKS API endpoint remains enabled so the operator's workstation can run kubectl and the Terraform Kubernetes/Helm providers. Its CIDR allowlist is required and rejects global IPv4/IPv6 CIDRs; use only your current trusted IP. The private endpoint is enabled too. The subnets auto-assign public IPs because this intentionally avoids a NAT Gateway. These are documented lab-only exceptions in `.trivyignore`, not a claim that the network is production-hardened. A production topology should use a private-only API endpoint and private worker subnets accessed by a VPC-connected operator/runner, plus NAT or the required VPC endpoints for outbound AWS service access. Those options have additional costs and require changing the deployment access path.

The KMS key is customer-managed and has automatic rotation enabled. It has a 7-day deletion window; do not schedule it for deletion while a live cluster still depends on it. AWS notes that EKS 1.28 and later already use envelope encryption by default, so the explicit key provides account-level key control rather than enabling encryption from zero. See [AWS EKS KMS encryption documentation](https://docs.aws.amazon.com/eks/latest/userguide/enable-kms.html).

## 3. Create the application/platform stack

```bash
cd ../stack
terraform init -reconfigure
terraform plan
```

The stack backend uses S3 native lock files. The `-reconfigure` flag is required because the prior stack backend configuration used the deprecated DynamoDB lock parameter. The backend remains the same S3 bucket/key; the state location is not changed.

Review the plan before applying. The stack reads VPC, subnet, and cluster-name outputs from `foundation/terraform.tfstate`; it no longer uses the old hard-coded IDs from the prior AWS account.

```bash
terraform apply
```

The stack creates the platform node group, encrypted gp3 storage class, SonarQube EC2 server, Traefik ingress controller, Argo CD, observability components, and application configuration. The first app sync may show image-pull errors until CI has pushed images to the new ECR repositories and updated `values-dev.yaml`; Argo CD self-heals after the image tag is updated.

After apply:

```bash
aws eks update-kubeconfig --name ztd-demo --region ap-south-1 --profile zero-to-prod
kubectl get nodes
kubectl get pods -A
kubectl get svc -n traefik
```

The Traefik LoadBalancer Service should eventually receive an AWS Network Load Balancer hostname. The sample `*.example.com` hosts are placeholders; for a smoke test, send the configured host header to the load balancer hostname or configure real DNS.

## 4. Configure GitHub Actions

Repository Settings → Secrets and variables → Actions:

Variables:
- `AWS_REGION=ap-south-1`
- `ECR_REGISTRY=921810470521.dkr.ecr.ap-south-1.amazonaws.com`

Secret:
- `AWS_DEPLOY_ROLE_ARN=arn:aws:iam::921810470521:role/ztd-capstone-ci`

Push a service change to `main` to trigger CI. The workflow builds and scans Docker images, pushes them to ECR, and updates the development Helm values file. Configure any SonarQube secrets required by PR checks if you intend to run that gate.

## Teardown

To turn off the application platform but keep the EKS foundation:

```bash
cd terraform/stack
terraform destroy
```

To remove the cluster and networking after stack teardown:

```bash
cd ../foundation
terraform destroy
```

Destroy stack before foundation. Keep bootstrap until both remote states are no longer needed. ECR repositories may contain image artifacts; decide whether to preserve them before deleting bootstrap. Destroying the foundation schedules the KMS key for deletion after its configured 7-day waiting period.
