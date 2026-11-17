# Authentik
# https://github.com/osinfra-io/factory

module "authentik_config" {
  source = "../../../../modules/kubernetes/authentik-config"

  application_launch_url = "https://dev.localhost/istio-test/auth"
  application_groups     = local.application_groups
  application_name       = "Development"
  application_slug       = "development-oidc"
  authentik_url          = "https://authentik.localhost"

  browser_group_policy_bindings = {
    agentgateway = {
      groups      = ["factory: agentgateway Admins"]
      host        = "https://agentgateway.localhost"
      icon        = "https://docs.osinfra.io/img/authentik/applications/agentgateway.svg"
      launch_url  = "https://agentgateway.localhost/ui/"
      name        = "agentgateway"
      policy_name = "agentgateway-browser-access"
    }
    development = {
      groups      = ["all"]
      host        = "https://dev.localhost"
      icon        = "https://docs.osinfra.io/img/authentik/applications/istio.svg"
      launch_url  = "https://dev.localhost/istio-test/auth"
      name        = "Istio"
      policy_name = "local-development-browser-access"
    }
    floor = {
      groups      = ["all"]
      hidden      = true
      host        = "https://floor.localhost"
      name        = "floor"
      policy_name = "floor-browser-access"
    }
    kagent = {
      groups      = ["factory: kagent Admins"]
      host        = "https://kagent.localhost"
      icon        = "https://docs.osinfra.io/img/authentik/applications/kagent.svg"
      launch_url  = "https://kagent.localhost/"
      name        = "kagent"
      policy_name = "kagent-browser-access"
    }
  }

  client_id = "development"

  default_authentication_stage_settings = module.authentik.default_authentication_stage_settings
  gateway_oidc_enabled                  = false
  google_internal_domains               = ["osinfra.io"]
  google_oauth_client_id                = var.google_oauth_client_id
  google_oauth_client_secret            = var.google_oauth_client_secret
  manage_default_authentication_stage   = true
  namespace                             = "authentik"
  openbao_application_icon              = "https://docs.osinfra.io/img/authentik/applications/openbao.svg"
  openbao_hostname                      = "openbao.localhost"
  outpost_authentik_url                 = "https://authentik.localhost"
  superuser_group_keys                  = ["factory/authentik-admins"]

  redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://dev.localhost/oauth2/callback"
    },
  ]
}

# Authentik
# https://github.com/osinfra-io/factory

module "authentik" {
  source = "../../../../modules/authentik"

  brand_domain = "authentik.localhost"
  brand_title  = "osinfra.io | Development"
  flow_title   = "Welcome to osinfra.io development!"
  policy_ids   = local.authentication_policy_ids
  stage_ids    = local.authentication_stage_ids
}

# Application Access
# https://github.com/osinfra-io/factory

module "team_access" {
  source = "../../../../modules/kubernetes/gateway-auth/team-access"

  environment = "sandbox"
  teams       = local.team_access_teams
}
