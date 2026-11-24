locals {
  agentgateway_admin_allow_manifest = merge(local.agentgateway_admin_deny_manifest, {
    metadata = {
      name      = "agentgateway-admin-ingress"
      namespace = local.agentgateway_namespace
    }
    spec = merge(local.agentgateway_admin_deny_manifest.spec, {
      action = "ALLOW"
      rules = [{
        from = [{
          source = {
            principals = ["cluster.local/ns/istio-ingress/sa/gateway-istio"]
          }
        }]
        to = [{
          operation = {
            ports = ["15000"]
          }
        }]
      }]
    })
  })

  agentgateway_admin_deny_manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "agentgateway-admin"
      namespace = local.agentgateway_namespace
    }
    spec = {
      action = "DENY"
      rules = [{
        from = [{
          source = {
            notPrincipals = ["cluster.local/ns/istio-ingress/sa/gateway-istio"]
          }
        }]
        to = [{
          operation = {
            ports = ["15000"]
          }
        }]
      }]
      selector = {
        matchLabels = {
          "gateway.networking.k8s.io/gateway-name" = "agentgateway-proxy"
        }
      }
    }
  }

  agentgateway_controller_allow_manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "agentgateway-controller-discovery"
      namespace = local.agentgateway_namespace
    }
    spec = {
      action = "ALLOW"
      rules = [{
        from = [{
          source = {
            principals = ["cluster.local/ns/${local.agentgateway_namespace}/sa/agentgateway-proxy"]
          }
        }]
        to = [{
          operation = {
            ports = ["9978"]
          }
        }]
      }]
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "agentgateway"
        }
      }
    }
  }

  agentgateway_hostname = local.global.agentgateway_hostname

  agentgateway_namespace = "agentgateway"

  agentgateway_policy_inputs = {
    "${local.cluster_name}-agentgateway-admin" = {
      host            = local.agentgateway_hostname
      mode            = "browser"
      path            = "/"
      required_groups = ["${local.cluster.team}: agentgateway Admins"]
    }
    "${local.cluster_name}-agentgateway-admin-${local.location}" = {
      host            = local.agentgateway_regional_hostname
      mode            = "browser"
      path            = "/"
      required_groups = ["${local.cluster.team}: agentgateway Admins"]
    }
  }

  agentgateway_regional_hostname = "${local.location}.${local.agentgateway_hostname}"

  agentgateway_routes = {
    agentgateway-admin = {
      backend_namespace = local.agentgateway_namespace
      backend_port      = 15000
      backend_service   = "agentgateway-proxy-admin"
      host              = local.agentgateway_hostname
      path              = "/"
    }
    "agentgateway-admin-${local.location}" = {
      backend_namespace = local.agentgateway_namespace
      backend_port      = 15000
      backend_service   = "agentgateway-proxy-admin"
      host              = local.agentgateway_regional_hostname
      path              = "/"
    }
  }

  authentik_extension_provider_name = "authentik"

  authentik_hostname = local.global.authentik_hostname

  # The issuer and JWKS URI are derived rather than read from the authentik-config state, which
  # runs after this stage.
  authentik_issuer_url = "https://${local.authentik_hostname}/application/o/gateway/"

  authentik_jwks_uri = "${local.authentik_issuer_url}jwks/"

  authentik_namespace = "authentik"

  authentik_regional_hostname = "${local.location}.${local.authentik_hostname}"

  # HTTPRoutes expose the authentik UI and OIDC endpoints on the shared gateway through both the
  # shared hostname and this zone's direct hostname.
  authentik_routes = {
    "authentik-${local.team_subdomain}" = {
      backend_namespace = local.authentik_namespace
      backend_port      = 80
      backend_service   = "authentik-server"
      host              = local.authentik_hostname
      path              = "/"
    }
    "authentik-${local.team_subdomain}-${local.location}" = {
      backend_namespace = local.authentik_namespace
      backend_port      = 80
      backend_service   = "authentik-server"
      host              = local.authentik_regional_hostname
      path              = "/"
    }
  }

  authentik_vhost_names = [
    "${local.authentik_hostname}:443",
    "${local.authentik_regional_hostname}:443",
  ]

  cluster_name = "${local.cluster.team}-${local.location}"

  # The paired region for multi-region failover.
  failover_to_region = module.core_helpers.region == "us-east1" ? "us-east4" : "us-east1"

  gateway_auth_browser_policy_inputs = merge({
    for item in local.gateway_auth_route_policy_items :
    "${local.cluster_name}-${item.key}" => item
  }, local.agentgateway_policy_inputs)

  gateway_auth_custom_authorization_policy_manifests = merge(concat(
    [{}],
    [for renderer in values(module.gateway_auth) : renderer.custom_authorization_policy_manifests],
  )...)

  gateway_auth_gateway_selector = {
    "gateway.networking.k8s.io/gateway-name" = "gateway"
  }

  gateway_auth_policies = {
    for key, item in local.gateway_auth_browser_policy_inputs :
    key => merge(
      item,
      module.gateway_auth["this"].resolved_policies[key],
      { cluster_name = local.cluster_name },
    )
    if var.runtime_enabled
  }

  gateway_auth_request_authentication_manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "RequestAuthentication"
    metadata = {
      name      = "gateway-authentik-jwt"
      namespace = "istio-ingress"
    }
    spec = {
      jwtRules = [
        {
          issuer  = local.authentik_issuer_url
          jwksUri = local.authentik_jwks_uri
        }
      ]
      targetRefs = [
        {
          group = "gateway.networking.k8s.io"
          kind  = "Gateway"
          name  = "gateway"
        }
      ]
    }
  }

  # Browser routes are authorized by the authentik outpost through the CUSTOM ext_authz policy.
  gateway_auth_route_policy_items = [
    {
      audiences       = []
      host            = local.global.team_hostname
      key             = "${local.cluster.team}-istio-test-istio-test-${local.team_subdomain}-global"
      mode            = "browser"
      path            = "/istio-test"
      public_paths    = local.istio_test_public_paths
      required_groups = ["all"]
      required_roles  = []
    },
    {
      audiences       = []
      host            = local.istio_test_regional_hostname
      key             = "${local.cluster.team}-istio-test-istio-test-${local.team_subdomain}-zonal"
      mode            = "browser"
      path            = "/istio-test"
      public_paths    = local.istio_test_public_paths
      required_groups = ["all"]
      required_roles  = []
    },
  ]

  global = data.terraform_remote_state.global.outputs

  istio_test_namespace = "${local.cluster.team}-istio-test"

  istio_test_public_paths = [
    "/istio-test/health",
    "/istio-test/metadata/*",
  ]

  istio_test_regional_hostname = "${local.location}.${local.global.team_hostname}"

  istio_test_routes = {
    "istio-test-${local.team_subdomain}" = {
      backend_namespace = local.istio_test_namespace
      backend_port      = 8080
      backend_service   = "istio-test"
      host              = local.global.team_hostname
      path              = "/istio-test"
    }
    "istio-test-${local.team_subdomain}-${local.location}" = {
      backend_namespace = local.istio_test_namespace
      backend_port      = 8080
      backend_service   = "istio-test-${local.location}"
      host              = local.istio_test_regional_hostname
      path              = "/istio-test"
    }
  }

  routes = merge(
    local.agentgateway_routes,
    local.authentik_routes,
    local.istio_test_routes,
    try(module.gateway_auth["this"].callback_routes, {}),
  )

  stage = "istio-manifests"

  team_subdomain = split(".", local.global.team_hostname)[0]
}
