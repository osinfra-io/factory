# Authentik
# https://github.com/osinfra-io/factory

module "authentik_config" {
  source = "../../../../tofu/modules/kubernetes/authentik/config"

  application_launch_url = "https://dev.localhost/istio-test/auth"
  application_groups     = local.application_groups
  application_name       = "Development"
  application_slug       = "development-oidc"
  authentik_url          = "https://authentik.localhost"
  branding = {
    domain     = "authentik.localhost"
    flow_title = "Welcome to osinfra.io development!"
    title      = "osinfra.io | Development"
  }

  browser_group_policy_bindings       = local.browser_group_policy_bindings
  cli_oidc_browser_keys               = ["floor"]
  client_id                           = "development"
  gateway_oidc_enabled                = false
  google_internal_domains             = ["osinfra.io"]
  google_oauth_client_id              = var.google_oauth_client_id
  google_oauth_client_secret          = var.google_oauth_client_secret
  manage_default_authentication_stage = true
  openbao_application_icon            = "https://docs.osinfra.io/img/authentik/applications/openbao.svg"
  openbao_hostname                    = "openbao.localhost"
  superuser_group_keys                = local.superuser_group_keys

  redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://dev.localhost/oauth2/callback"
    },
  ]
}

module "authentik_regional_config" {
  source = "../../../../tofu/modules/kubernetes/authentik/regional/config"

  authentik_url      = "https://authentik.localhost"
  namespace          = "authentik"
  proxy_provider_ids = module.authentik_config.proxy_provider_ids
}

# Application Access
# https://github.com/osinfra-io/factory

module "team_access" {
  source = "../../../../tofu/modules/kubernetes/authentik/config/team-access"

  environment = var.environment
  teams       = local.team_access_teams
}
