# authentik is one logical service, so it is configured once per environment rather than per cluster.
module "authentik_config" {
  source = "../../modules/kubernetes/authentik/config"

  application_groups = local.application_groups
  authentik_url      = local.authentik_url

  branding = {
    domain     = local.authentik_hostname
    flow_title = local.flow_title
    title      = local.brand_title
  }

  browser_group_policy_bindings       = local.browser_group_policy_bindings
  google_internal_domains             = ["osinfra.io"]
  google_oauth_client_id              = var.google_oauth_client_id
  google_oauth_client_secret          = var.google_oauth_client_secret
  manage_default_authentication_stage = true
  openbao_hostname                    = local.openbao_hostname
  redirect_uris                       = local.redirect_uris
  superuser_group_keys                = local.superuser_group_keys
}

module "team_access" {
  source = "../../modules/kubernetes/authentik/config/team-access"

  environment = module.core_helpers.environment
  teams       = var.teams
}

module "authentik_regional_config" {
  source = "../../modules/kubernetes/authentik/regional/config"

  authentik_url      = local.authentik_url
  namespace          = local.namespace
  proxy_provider_ids = module.authentik_config.proxy_provider_ids
}
