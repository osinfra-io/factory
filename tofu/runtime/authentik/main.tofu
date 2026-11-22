module "authentik" {
  source = "../../modules/kubernetes/authentik/regional"

  depends_on = [kubernetes_secret_v1.authentik]

  for_each = local.instances

  cloud_sql_connection_name        = local.global.cloud_sql_connection_name
  existing_secret                  = kubernetes_secret_v1.authentik[each.key].metadata[0].name
  external_database_name           = local.global.database_name
  external_database_user           = local.global.database_user
  google_service_account_email     = local.global.cloud_sql_service_account_email
  namespace                        = local.namespace
  server_replicas                  = var.server_replicas
  server_resources_requests_cpu    = var.server_resources_requests_cpu
  server_resources_requests_memory = var.server_resources_requests_memory
  worker_replicas                  = var.worker_replicas
  worker_resources_requests_cpu    = var.worker_resources_requests_cpu
  worker_resources_requests_memory = var.worker_resources_requests_memory
}

# Under the mesh's default-deny AuthorizationPolicy an ambient authentik would be unreachable.
# Allow the ingress gateway to reach every authentik endpoint, since it is the identity provider.
resource "kubernetes_manifest" "authentik_allow_gateway" {
  for_each = local.instances

  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"

    metadata = {
      name      = "authentik-allow-gateway"
      namespace = local.namespace
    }

    spec = {
      action = "ALLOW"
      rules = [
        {
          from = [
            {
              source = {
                namespaces = ["istio-ingress"]
              }
            }
          ]
        }
      ]

      selector = {
        matchLabels = {
          "app.kubernetes.io/component" = "server"
          "app.kubernetes.io/instance"  = "authentik"
          "app.kubernetes.io/name"      = "authentik"
        }
      }
    }
  }
}

resource "kubernetes_secret_v1" "authentik" {
  for_each = local.instances

  data = local.global.secret_env

  metadata {
    name      = local.secret_name
    namespace = local.namespace
  }

  type = "Opaque"
}
