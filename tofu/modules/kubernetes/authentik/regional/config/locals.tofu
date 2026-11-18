# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  embedded_outpost_name = "authentik Embedded Outpost"

  outpost_authentik_url = var.outpost_authentik_url != null ? var.outpost_authentik_url : var.authentik_url

  outpost_config = jsonencode({
    authentik_host = local.outpost_authentik_url
  })

  # Istio ext_authz targets the embedded outpost over the authentik-server HTTP Service.
  # https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_envoy
  outpost_service_name = "authentik-server"

  outpost_service_port = 80
}
