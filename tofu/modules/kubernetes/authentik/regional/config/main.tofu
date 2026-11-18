# Authentik Outpost
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/outpost

# The embedded outpost runs in the regional authentik-server pods and serves the instance's proxy
# providers locally for Istio ext_authz.
resource "authentik_outpost" "embedded" {
  config             = local.outpost_config
  name               = local.embedded_outpost_name
  protocol_providers = var.proxy_provider_ids
  type               = "proxy"
}
