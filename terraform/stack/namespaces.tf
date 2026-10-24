# Dedicated application, observability, GitOps, and ingress namespaces.
# The foundation root owns the cluster; this stack adds namespaces only.

locals {
  namespace_names = toset(["dev", "staging", "prod", "observability", "argocd", "traefik"])
}

resource "kubernetes_namespace" "this" {
  for_each = local.namespace_names

  metadata {
    name = each.value

    labels = {
      project = var.project
    }
  }
}
