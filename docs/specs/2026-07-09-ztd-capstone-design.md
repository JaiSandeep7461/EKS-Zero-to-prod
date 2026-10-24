> **Fresh-account note (October 2026):** This document records the original shared-cluster design. The current implementation creates its own VPC and EKS cluster in `terraform/foundation/`, then deploys workloads in `terraform/stack/`. Use [the fresh-account runbook](../runbooks/fresh-account-deploy.md) as the authoritative deployment order and current account/network configuration.

# ztd-capstone — Design Spec

**Date:** 2026-07-09
**Status:** Approved
**Repo:** https://github.com/Infrathrone-Devops-Park/ztd-capstone

A production-grade DevOps capstone: a polyglot e-commerce microservice app with full CI/CD (GitHub Actions + SonarQube + Trivy), Infrastructure-as-Code (Terraform), Kubernetes deployment to an existing EKS cluster, and a complete observability stack (Prometheus, Grafana, Loki, Promtail, Tempo, OpenTelemetry).

---

## 1. Goals & Constraints

**Goals**
- 3–4 polyglot microservices demonstrating realistic production patterns.
- GitHub Actions CI/CD with multiple workflows and a trunk-based branching strategy.
- SonarQube (self-hosted on EC2) + Trivy wired into the pipeline as quality/security gates.
- Full observability: metrics, logs, traces — dashboards provisioned from git.
- All **configuration** in git; **no secrets** in git.
- Single `terraform apply` to stand the whole stack up; single `terraform destroy` to tear it down (cost switch), and re-apply "just works."

**Hard constraints**
- Target cluster is the **existing shared** EKS cluster `arn:aws:eks:ap-south-1:514422154867:cluster/ztd-demo`. Terraform must **never** manage or destroy the base cluster or its `ingress-nginx`.
- Base cluster nodes are 2× `t3.small` (~4 GB RAM total) — too small for the full stack. A dedicated Terraform-managed nodegroup provides capacity.
- AWS profile: `infrathrone-new` (account `514422154867`, region `ap-south-1`).
- Commits authored as **SaiPisey2 <piseysai0202@gmail.com>**;

**Discovered cluster facts (2026-07-09)**
- Nodes: 2× t3.small, Kubernetes v1.31, EKS.
- `ingress-nginx` present as **NodePort** (no cloud LB), namespaces: default, ingress-nginx, kube-system, local-path-storage.
- StorageClasses: `gp2` (aws-ebs), `local-path` (default), `ztd-fast` (local-path, expandable). EBS CSI driver installed.
- No monitoring namespace yet.

---

## 2. Architecture Overview

```
                          ┌────────────────────────────────────────────┐
   GitHub (monorepo)      │        EKS cluster: ztd-demo (shared)        │
   ┌───────────────┐      │                                              │
   │ services/*    │      │  TF-managed nodegroup (2× t3.large,          │
   │ deploy/*      │      │   label workload=platform)                   │
   │ terraform/*   │      │   ┌────────────┐   ┌───────────────────────┐ │
   │ .github/*     │      │   │ app (Helm) │   │ observability (Helm)  │ │
   └──────┬────────┘      │   │ frontend   │   │ kube-prometheus-stack │ │
          │ push/PR/tag   │   │ api-gateway│   │ loki + promtail       │ │
          ▼               │   │ orders     │──▶│ tempo + otel-collector│ │
   ┌───────────────┐      │   │ catalog    │   │ grafana (dashboards)  │ │
   │ GitHub Actions│──────┼──▶│ postgres   │   └───────────────────────┘ │
   │ build/scan/   │ ECR  │   └────────────┘                             │
   │ push/deploy   │      │        ▲ ingress-nginx (existing, NodePort)  │
   └──────┬────────┘      └────────┼─────────────────────────────────────┘
          │ SonarQube scan          │
          ▼                         │
   ┌───────────────┐                │
   │ SonarQube EC2 │  (TF-managed, t3.medium, docker-compose)
   └───────────────┘
```

Deployment is via Helm. Observability agents run in-cluster on the dedicated nodegroup and ship to in-cluster backends. CI builds and scans images, pushes to ECR, and deploys via Helm. Terraform (stack layer) can also install observability + app so a single `apply` yields a fully wired platform referencing images already in ECR.

---

## 3. Microservices (polyglot, e-commerce)

| Service | Language / runtime | Responsibility | Image strategy |
|---|---|---|---|
| `frontend` | React (Vite) + Nginx | Storefront UI; generates realistic traffic | multi-stage → `nginx:alpine`, non-root |
| `api-gateway` | Node/TS (Fastify) | Edge routing, request auth, OTLP trace root, aggregates downstream | multi-stage → distroless node, non-root |
| `orders` | Python (FastAPI) | Order lifecycle; persists to Postgres; calls catalog | multi-stage → distroless python, non-root |
| `catalog` | Go | Product catalog; fast, tiny | static build → distroless/`scratch`, non-root |

- **Data:** in-cluster **Postgres** (StatefulSet, `gp2` PVC). No RDS (keeps everything in destroy scope, avoids standing cost). Data loss on destroy is acceptable for a demo.
- **Every service exposes:**
  - `/metrics` — Prometheus format (scraped via ServiceMonitor).
  - OTLP export → OpenTelemetry Collector (traces; gateway starts the trace, propagates context downstream).
  - Structured JSON logs to stdout (tailed by Promtail).
  - `/healthz` (liveness) and `/readyz` (readiness).
- **Contracts:** gateway → catalog (read products), gateway → orders (create/list orders), orders → catalog (validate product), orders → postgres. Traces span the full chain for the service-map dashboard.

**Rationale:** 3 backend languages + a frontend give a genuine multi-language showcase for Sonar (per-language analyzers), Trivy (different base images), and a build matrix, while staying light enough to run on the dedicated nodegroup.

---

## 4. Repo Layout (monorepo)

```
ztd-capstone/
├── services/
│   ├── frontend/        # React+Vite src, Dockerfile, tests, sonar-project.properties, .env.example
│   ├── api-gateway/     # Fastify TS src, Dockerfile, tests, sonar-project.properties, .env.example
│   ├── orders/          # FastAPI src, Dockerfile, tests, sonar-project.properties, .env.example
│   └── catalog/         # Go src, Dockerfile, tests, sonar-project.properties, .env.example
├── deploy/
│   ├── helm/ztd-capstone/            # umbrella app chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml               # defaults
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   ├── values-prod.yaml
│   │   └── templates/                # per-service Deploy/SVC/HPA/PDB/NetPol/ServiceMonitor + postgres StatefulSet + Ingress
│   └── observability/                # values + dashboards + datasources (all in git)
│       ├── kube-prometheus-stack.values.yaml
│       ├── loki.values.yaml
│       ├── promtail.values.yaml
│       ├── tempo.values.yaml
│       ├── otel-collector.values.yaml
│       └── dashboards/*.json
├── terraform/
│   ├── bootstrap/       # local state: S3 state bucket + DynamoDB lock + ECR repos (persistent, ~never destroyed)
│   └── stack/           # S3 backend: nodegroup + SonarQube EC2 + observability + app (the cost toggle)
├── .github/workflows/   # pr-checks.yml, ci.yml, release.yml, terraform.yml
├── docs/specs/          # this spec + future design docs
├── .gitignore           # .env, *.tfvars, *.pem, kubeconfig
└── README.md
```

---

## 5. Terraform — Single-Command Stack

Two roots to resolve the state chicken-egg and to protect image durability across cost cycles.

### 5.1 `terraform/bootstrap/` (persistent, local state, run once)
Creates:
- **S3 bucket** for remote state (versioned, encrypted, public-access-blocked).
- **DynamoDB table** for state locking.
- **ECR repositories** (one per service) with lifecycle policy (keep last N images).

Idle cost ≈ $0. Rarely destroyed. This is "S3 state managed by Terraform," living in its own root. ECR is here (not in `stack/`) so `destroy`→`apply` of the stack keeps images intact and "just works."

### 5.2 `terraform/stack/` (the cost toggle, S3 backend)
`terraform apply` creates / `terraform destroy` removes:
- **EKS managed nodegroup** on the existing `ztd-demo` cluster — 2× `t3.large`, label `workload=platform`, sized for full observability + app.
- **SonarQube EC2** — `t3.medium`, security group (SSH from operator IP, 9000 for Sonar), Elastic IP, `gp2` root volume, `user_data` running docker-compose (SonarQube Community + its Postgres). DB password sourced from an SSM parameter written by TF from a sensitive var.
- **Kubernetes/Helm resources** (via `helm` + `kubernetes` providers): namespaces (`dev`, `staging`, `prod`, `observability`), kube-prometheus-stack, Loki, Promtail, Tempo, OTel Collector, Grafana datasources + dashboards (ConfigMaps), and the app umbrella chart (referencing ECR images/tags).

**Never manages:** the `ztd-demo` cluster control plane, its default nodegroup, or `ingress-nginx`. Destroy therefore cannot harm shared infra.

**Providers:** `aws` (profile `infrathrone-new`), `helm`, `kubernetes` (auth to the existing cluster via data sources / `aws eks get-token`).

### 5.3 Operator workflow
```bash
# one-time
cd terraform/bootstrap && terraform init && terraform apply

# daily cost toggle
cd terraform/stack && terraform apply    # whole platform UP, wired
cd terraform/stack && terraform destroy  # whole platform DOWN (cluster untouched)
```

---

## 6. CI/CD — GitHub Actions

### 6.1 Branching strategy (trunk-based)
- `main` — protected, always deployable. Requires PR, passing checks, and Sonar quality gate.
- `feature/*` — short-lived, branched from `main`, merged via **squash** PR.
- Releases via annotated git **tags** `v*`.
- Environments = namespaces: `dev` (auto-deploy on merge to main), `staging` (deploy on tag), `prod` (tag + GitHub Environment **manual approval** gate).

### 6.2 Workflows
| Workflow | Trigger | Steps |
|---|---|---|
| `pr-checks.yml` | PR to `main` | Path-filter changed services → per-service lint + unit tests → **SonarQube** scan (quality gate blocks merge) → **Trivy** fs + config/IaC scan |
| `ci.yml` | push to `main` | Build changed images → **Trivy image** scan (fail on HIGH/CRITICAL) → **cosign** sign + SBOM → push to **ECR** → `helm upgrade` to `dev` |
| `release.yml` | tag `v*` | Pull signed images → deploy `staging` → **manual approval** → deploy `prod` |
| `terraform.yml` | PR touching `terraform/**` / manual dispatch | `fmt` + `validate` + `tflint` + `plan` on PR; `apply` on manual dispatch |

- AWS auth via **GitHub OIDC → IAM role** (no long-lived keys).
- Sonar server = the EC2 host; `SONAR_TOKEN`, `SONAR_HOST_URL` in GH secrets.
- Trivy gates the build; results uploaded as SARIF to GitHub Security tab.

---

## 7. Observability

| Signal | Source | Pipeline | Store | View |
|---|---|---|---|---|
| Metrics | app `/metrics`, node-exporter, kube-state-metrics | ServiceMonitors → Prometheus | Prometheus TSDB | Grafana |
| Logs | stdout JSON | Promtail (DaemonSet) | Loki | Grafana |
| Traces | app OTLP | OTel Collector | Tempo | Grafana (trace↔log correlation) |

**Dashboards (committed as JSON, auto-provisioned):**
1. **Service RED** — request rate, error rate, duration per service (Prometheus).
2. **Logs** — log volume + error stream, filterable by service (Loki).
3. **Traces** — latency percentiles + service map (Tempo).
4. **Cluster health** — node/pod CPU, memory, restarts (Prometheus).

Grafana datasources (Prometheus, Loki, Tempo) provisioned from git. Retention kept modest (fits the nodegroup); values tuned in `deploy/observability/*.values.yaml`.

---

## 8. Production Best Practices

- **Images:** multi-stage, distroless/alpine, **non-root**, pinned bases, minimal layers.
- **Kubernetes:** resource requests/limits on every container, **HPA**, **PodDisruptionBudget**, **NetworkPolicies** (default-deny + explicit allows), liveness/readiness probes, `securityContext` (readOnlyRootFilesystem, drop caps).
- **Supply chain:** Trivy (fs, config, image) gating; **cosign** signatures; **SBOM** generation; ECR lifecycle + scan-on-push.
- **Secrets:** none in git. `.env` (gitignored) + `.env.example` templates for local; GitHub Actions Secrets for CI; materialized into k8s Secrets at deploy time; SonarQube DB pass via SSM.
- **Quality:** SonarQube quality gate mandatory; per-language coverage reports fed to Sonar.
- **IaC hygiene:** `terraform fmt`, `validate`, `tflint`, `plan`-on-PR; least-privilege IAM/IRSA; remote state with locking.
- **Repo governance:** branch protection on `main`, required reviews, required status checks, signed/verified commits authored as the user.

---

## 9. Out of Scope / Non-goals

- No RDS or other managed data stores (in-cluster Postgres only).
- No management of the base `ztd-demo` cluster or `ingress-nginx`.
- No service mesh (Istio/Linkerd) — OTel SDK-level tracing is sufficient.
- No multi-region / DR.
- Secrets management beyond `.env` + GH Secrets + k8s Secrets (no Vault/SOPS).

---

## 10. Build Phases (for the implementation plan)

1. **Bootstrap TF** — S3 state, DynamoDB, ECR.
2. **App services** — 4 services with health/metrics/tracing/logs, Dockerfiles, tests, local docker-compose for dev.
3. **Helm umbrella chart** — per-service templates + per-env values + Postgres + ingress.
4. **Stack TF** — nodegroup + SonarQube EC2 + observability + app installs.
5. **Observability config** — stack values + datasources + dashboards.
6. **GitHub Actions** — pr-checks, ci, release, terraform workflows + OIDC role.
7. **Docs & README** — runbook (apply/destroy, access URLs, demo script).
8. **End-to-end validation** — apply → traffic → dashboards populate → PR flow → sonar/trivy gates → destroy → re-apply.
