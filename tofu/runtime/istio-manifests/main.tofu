module "gateway_auth" {
  source = "../../modules/kubernetes/istio/regional/gateway-auth"

  for_each = local.instances

  extension_provider_name = local.authentik_extension_provider_name
  outpost_namespace       = local.authentik_namespace
  policies                = local.gateway_auth_browser_policy_inputs
}

module "istio_manifests" {
  source = "../../modules/kubernetes/istio/regional/manifests"

  depends_on = [
    kubernetes_service_v1.agentgateway_admin,
  ]

  for_each = local.instances

  failover_from_region = module.core_helpers.region
  failover_to_region   = local.failover_to_region
  routes               = local.routes
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "agentgateway_admin_allow" {
  for_each = local.instances

  manifest = local.agentgateway_admin_allow_manifest
}

resource "kubernetes_manifest" "agentgateway_admin_authorization" {
  for_each = local.instances

  manifest = local.agentgateway_admin_deny_manifest
}

resource "kubernetes_manifest" "agentgateway_controller_discovery" {
  for_each = local.instances

  manifest = local.agentgateway_controller_allow_manifest
}

resource "kubernetes_manifest" "gateway_auth_custom_authorization_policy" {
  for_each = local.gateway_auth_custom_authorization_policy_manifests

  manifest = each.value
}

resource "kubernetes_manifest" "gateway_auth_request_authentication" {
  for_each = local.instances

  manifest = local.gateway_auth_request_authentication_manifest
}

resource "kubernetes_manifest" "gateway_authentik_inbound_header_strip_filter" {
  for_each = local.instances

  manifest = module.gateway_auth[each.key].inbound_header_strip_filter_manifest
}

resource "kubernetes_manifest" "gateway_authentik_jwt_bypass_filter" {
  for_each = local.instances

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "EnvoyFilter"
    metadata = {
      annotations = {
        # IST0133: EnvoyFilters are inherently low-level; this warning is expected.
        "galley.istio.io/analyze-suppress" = "IST0133"
      }
      name      = "gateway-authentik-jwt-bypass"
      namespace = "istio-ingress"
    }
    spec = {
      # The gateway-wide RequestAuthentication (gateway-authentik-jwt) rejects any request carrying
      # an Authorization: Bearer token that is not a valid JWT for the configured issuer. authentik
      # authenticates its own API and OIDC token clients with opaque Bearer tokens, so the jwt_authn
      # filter is disabled for the authentik virtual hosts only; every other host still enforces JWT.
      configPatches = [
        for vhost_name in local.authentik_vhost_names : {
          applyTo = "VIRTUAL_HOST"
          match = {
            context = "GATEWAY"
            routeConfiguration = {
              vhost = {
                name = vhost_name
              }
            }
          }
          patch = {
            operation = "MERGE"
            value = {
              typed_per_filter_config = {
                "envoy.filters.http.jwt_authn" = {
                  "@type"  = "type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.PerRouteConfig"
                  disabled = true
                }
              }
            }
          }
        }
      ]

      workloadSelector = {
        labels = local.gateway_auth_gateway_selector
      }
    }
  }
}

# https://github.com/osinfra-io/pt-arche-kubernetes-istio/issues/147 tracks investigating
# the cost and observability trade-offs before re-enabling Istio metrics.
resource "kubernetes_manifest" "istio_telemetry" {
  depends_on = [
    module.istio_manifests
  ]

  for_each = local.instances

  manifest = {
    apiVersion = "telemetry.istio.io/v1"
    kind       = "Telemetry"

    metadata = {
      name      = "mesh-default"
      namespace = "istio-system"
    }

    spec = {
      metrics = [
        {
          providers = [
            {
              name = "prometheus"
            }
          ]

          overrides = [
            {
              disabled = true

              match = {
                metric = "ALL_METRICS"
                mode   = "CLIENT_AND_SERVER"
              }
            }
          ]
        }
      ]
    }
  }
}

# Kubernetes Service Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "agentgateway_admin" {
  depends_on = [
    kubernetes_manifest.agentgateway_admin_allow,
    kubernetes_manifest.agentgateway_admin_authorization,
    kubernetes_manifest.gateway_auth_custom_authorization_policy,
  ]

  for_each = local.instances

  metadata {
    name      = "agentgateway-proxy-admin"
    namespace = local.agentgateway_namespace
  }

  spec {
    port {
      name        = "http-admin"
      port        = 15000
      target_port = 15000
    }

    selector = {
      "gateway.networking.k8s.io/gateway-name" = "agentgateway-proxy"
    }
    type = "ClusterIP"
  }
}
