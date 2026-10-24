# EKS-Zero-to-prod

Production-grade DevOps capstone: polyglot e-commerce microservices with GitHub Actions CI/CD, SonarQube + Trivy gates, Terraform IaC, Kubernetes deployment to Amazon EKS, and observability with Prometheus, Grafana, Loki, Promtail, Tempo, and OpenTelemetry.

## Repository layout

- `services/` — frontend, API gateway, orders, and catalog microservices
- `deploy/` — Helm chart, Argo CD Applications, ingress, and observability configuration
- `terraform/bootstrap/` — persistent S3 state bucket, lock table, ECR repositories, and GitHub Actions OIDC role
- `terraform/foundation/` — fresh VPC, public subnets, EKS control plane, baseline system node group, and EBS CSI driver
- `terraform/stack/` — dedicated platform node group, SonarQube EC2, Traefik ingress, Argo CD, application namespaces, and observability

## Fresh-account deployment

Follow [the fresh-account deployment runbook](docs/runbooks/fresh-account-deploy.md). The expected order is:

1. Apply `terraform/bootstrap` once to create persistent state/ECR/OIDC resources.
2. Apply `terraform/foundation` to create the new VPC and `ztd-demo` EKS cluster.
3. Apply `terraform/stack` to create the platform node group and application platform.
4. Configure GitHub Actions repository variables/secrets and run CI to build/push images. Argo CD syncs the development application from this repository.

Do not apply `terraform/stack` before the foundation layer exists. Stack Terraform reads foundation outputs from S3 and intentionally does not own the VPC or EKS control plane.

## Cost and teardown

- `terraform/stack` is the workload cost toggle. Destroy it first to remove the platform node group, SonarQube, ingress, Argo CD, and observability resources.
- To remove the cluster and networking too, destroy `terraform/foundation` after stack teardown.
- Keep `terraform/bootstrap` and its S3 state bucket while either foundation or stack state still exists. Destroying bootstrap prematurely can delete Terraform state/ECR repositories and prevent safe teardown.
- The fresh-account demo uses tagged public subnets and no NAT Gateway to avoid NAT hourly charges. Worker nodes therefore use public subnets. The EKS API endpoint and SonarQube port 9000 are publicly reachable by default; review and narrow their CIDR variables where your CI setup permits.

## Validation

The Terraform workflow runs `fmt`, `validate`, and TFLint for the bootstrap, foundation, and stack roots. AWS infrastructure plans and applies should be reviewed and run by an operator with the intended AWS profile.
