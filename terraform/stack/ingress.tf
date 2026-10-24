# Traefik is a maintained ingress-controller alternative to the retired
# ingress-nginx project. The LoadBalancer Service requests a public NLB from
# the tagged public subnets created by terraform/foundation.

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "42.1.3"
  namespace  = kubernetes_namespace.this["traefik"].metadata[0].name
  timeout    = 900

  values = [
    yamlencode({
      deployment = {
        replicas = 2
      }
      nodeSelector = {
        workload = "platform"
      }
      ingressClass = {
        enabled        = true
        isDefaultClass = false
      }
      service = {
        enabled = true
        type    = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
        }
      }
    })
  ]
}
