# istio-test reports cluster status and gives end-to-end connectivity checks through the shared gateway.
resource "kubernetes_deployment_v1" "istio_test" {
  for_each = local.instances

  metadata {
    name      = "istio-test"
    namespace = local.namespace
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          image             = "${local.registry}:${var.image_version}"
          image_pull_policy = "Always"

          liveness_probe {
            failure_threshold = 5

            http_get {
              path = "/istio-test/health"
              port = "8080"
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
          }

          name = "istio-test"

          port {
            container_port = 8080
          }

          readiness_probe {
            failure_threshold = 5

            http_get {
              path = "/istio-test/health"
              port = "8080"
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }

            requests = {
              cpu    = "25m"
              memory = "64Mi"
            }
          }
        }

        topology_spread_constraint {
          label_selector {
            match_labels = local.labels
          }

          max_skew           = 1
          topology_key       = "kubernetes.io/zone"
          when_unsatisfiable = "ScheduleAnyway"
        }
      }
    }
  }
}

# ztunnel enforces only L4 attributes (no waypoints), so the policy matches on source principal.
resource "kubernetes_manifest" "istio_test" {
  for_each = local.instances

  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"

    metadata = {
      name      = "istio-test"
      namespace = local.namespace
    }

    spec = {
      action = "ALLOW"
      rules = [
        {
          from = [
            {
              source = {
                principals = ["cluster.local/ns/istio-ingress/sa/gateway-istio"]
              }
            }
          ]
        }
      ]

      selector = {
        matchLabels = local.labels
      }
    }
  }
}

# Both services are reachable from other clusters over the ambient east-west gateways.
resource "kubernetes_service_v1" "istio_test" {
  for_each = local.instances

  metadata {
    labels = {
      "istio.io/global" = "true"
    }

    name      = "istio-test"
    namespace = local.namespace
  }

  spec {
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }

    selector = local.labels
    type     = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "istio_test_zonal" {
  for_each = local.instances

  metadata {
    labels = {
      "istio.io/global" = "true"
    }

    name      = "istio-test-${local.location}"
    namespace = local.namespace
  }

  spec {
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }

    selector = local.labels
    type     = "ClusterIP"
  }
}
