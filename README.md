# zero-to-prod

Production-style DevOps capstone: polyglot e-commerce microservices with GitHub Actions CI/CD, SonarQube + Trivy gates, Terraform IaC, deployment to Amazon EKS, and observability (Prometheus, Grafana, Loki, Promtail, Tempo, and OpenTelemetry).

## Repository layout

- `services/` — frontend, API gateway, orders, and catalog services.
- `deploy/` — Helm charts, Argo CD applications, and observability configuration.
- `terraform/bootstrap/` — persistent Terraform state bucket, lock table, ECR repositories, and GitHub Actions OIDC role.
- `terraform/foundation/` — project-owned VPC, public/private subnets, NAT Gateway, and EKS control plane.
- `terraform/stack/` — EKS managed node group, SonarQube EC2 host, namespaces, Argo CD, and observability stack.
- `.github/workflows/` — CI/CD and Terraform validation workflows.

## First deployment to a fresh AWS account

The defaults target AWS account `921810470521`, region `ap-south-1` (Mumbai), and AWS CLI profile `zero-to-prod`. Review these values before applying.

Run these commands from Git Bash. The first layer uses local state; the next two use the S3 bucket created by bootstrap.

```bash
export AWS_PROFILE=zero-to-prod
export AWS_REGION=ap-south-1

cd terraform/bootstrap
terraform init
terraform plan
terraform apply

cd ../foundation
terraform init
terraform plan
terraform apply

cd ../stack
terraform init
terraform plan
terraform apply
```

Review every plan before applying. The foundation creates a dedicated VPC and a NAT Gateway. NAT Gateway and EKS have recurring charges while they exist. The EKS public API endpoint is open to public IP ranges by default so a GitHub-hosted runner can reach it; IAM authentication is still required. Restrict `cluster_endpoint_public_access_cidrs` where practical.

## GitHub Actions configuration

After bootstrap, add the Terraform output `ci_role_arn` as the repository Actions secret `AWS_DEPLOY_ROLE_ARN`. Add the Actions variables:

- `AWS_REGION` = `ap-south-1`
- `ECR_REGISTRY` = `921810470521.dkr.ecr.ap-south-1.amazonaws.com`

No long-lived AWS access keys are needed by GitHub Actions; the workflow assumes the IAM role through OIDC.

## Cost-conscious teardown

Destroy the stack before the foundation. This removes the platform node group and application/observability resources before the EKS control plane and VPC are removed.

```bash
cd terraform/stack
terraform destroy

cd ../foundation
terraform destroy
```

Keep `terraform/bootstrap` until you are sure you no longer need the remote state bucket, lock table, and ECR repositories. Destroying bootstrap also removes these persistent resources. The bootstrap bucket has `force_destroy = true`, so its objects can be deleted with it.

## Notes

The foundation and stack manage resources dedicated to this repository. They do not reuse the account's default VPC or hardcoded subnet IDs from the original upstream account.
