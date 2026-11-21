# Dev deployment validation runbook

This runbook verifies the delivery path:

```
main push
  -> CI tests
  -> Docker build
  -> Trivy HIGH/CRITICAL gate
  -> ECR
  -> Cosign + SBOM
  -> values-dev.yaml image-tag bump
  -> Argo CD auto-sync
  -> EKS dev rollout
  -> smoke test
```

## What is automatic

The `ci.yml` workflow builds and scans the four service images. When all matrix jobs pass, the workflow updates `deploy/helm/ztd-capstone/values-dev.yaml` with the immutable `sha-<gitsha>` tag.

The Argo CD root Application watches `deploy/argocd/apps/`. The dev Application is configured for automated sync, pruning, and self-healing. Therefore the CI workflow does not directly deploy application manifests to the cluster.

## Smoke test

`.github/workflows/dev-deployment-smoke-test.yml` runs after a successful `ci` workflow and can also be started manually.

It:

1. Authenticates to AWS through GitHub OIDC.
2. Builds kubeconfig for the EKS cluster.
3. Waits for catalog, orders, api-gateway, and frontend deployments in `dev`.
4. Waits for the application pods to become Ready.
5. Port-forwards the frontend and API gateway services through the Kubernetes API.
6. Calls their `/healthz` endpoints.
7. Prints deployment, service, pod, and recent event evidence.

The smoke test is validation-only. It does not call `kubectl apply`, `helm upgrade`, or mutate the application state.

## Required GitHub configuration

The `dev` Environment should provide:

- `AWS_DEPLOY_ROLE_ARN` secret
- `AWS_REGION` variable
- `EKS_CLUSTER_NAME` variable

The assumed IAM role must have EKS access scoped to the `dev` namespace. It should not be changed to cluster-admin merely to make the smoke test work.

## Rollback

Because application images are immutable and the deployed tag is stored in Git, rollback is a Git change:

1. Identify the last known-good image tag.
2. Change `image.tag` in `deploy/helm/ztd-capstone/values-dev.yaml` to that immutable tag.
3. Open a PR and let the normal PR/security checks run.
4. Merge the PR.
5. CI will verify/build the resulting commit and update the GitOps tag.
6. Argo CD will reconcile the desired state.

Do not manually edit live Deployments as the normal rollback mechanism; that creates drift from Git.

## Production promotion

Staging and production are intentionally not auto-synced by the Argo CD Applications. Promotion should remain an explicit release action with the configured GitHub Environment approval gates.

Before calling the project production-ready, verify the actual EKS cluster has:

- healthy Argo CD Applications;
- healthy Prometheus/Grafana/Loki/Tempo/OTel components;
- working Traefik LoadBalancer;
- valid DNS/TLS for the chosen hostname;
- healthy Postgres persistence;
- working HPA/PDB behavior;
- successful rollback evidence.

## Cost control

This project uses AWS resources that can continue generating charges after the demo. Destroy the Terraform stack/foundation/bootstrap in the documented reverse order when the environment is no longer needed.
