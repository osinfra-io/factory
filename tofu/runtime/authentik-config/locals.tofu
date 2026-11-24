locals {
  agentgateway_hostname = local.istio_global.agentgateway_hostname

  agentgateway_regional_hostnames = {
    for location in var.locations : location => "${location}.${local.agentgateway_hostname}"
  }

  # Managed groups require the Google source, so they are declared only when credentials are supplied.
  application_groups = local.google_oauth_enabled ? module.team_access.application_groups : {}

  authentik_hostname = local.istio_global.authentik_hostname

  authentik_token = data.terraform_remote_state.authentik_global.outputs.secret_env["AUTHENTIK_BOOTSTRAP_TOKEN"]

  authentik_url = "https://${local.authentik_hostname}"

  brand_title = module.core_helpers.environment == "production" ? "osinfra.io" : "osinfra.io | ${title(module.core_helpers.environment)}"

  browser_group_policy_bindings = merge(
    {
      agentgateway = {
        groups      = ["${var.team}: agentgateway Admins"]
        host        = "https://${local.agentgateway_hostname}"
        policy_name = "agentgateway-browser-access"
      }
      istio-test = {
        groups      = ["all"]
        host        = "https://${local.team_hostname}"
        icon        = "https://docs.osinfra.io/img/authentik/applications/istio.svg"
        launch_url  = "https://${local.team_hostname}/istio-test/auth"
        name        = "Istio"
        policy_name = "${var.team}-browser-access"
      }
    },
    {
      for location, hostname in local.agentgateway_regional_hostnames : "agentgateway-${location}" => {
        groups      = ["${var.team}: agentgateway Admins"]
        host        = "https://${hostname}"
        policy_name = "agentgateway-browser-access-${location}"
      }
    },
    {
      for location in var.locations : "istio-test-${location}" => {
        groups      = ["all"]
        hidden      = true
        host        = "https://${location}.${local.team_hostname}"
        policy_name = "${var.team}-browser-access"
      }
    },
  )

  flow_title = module.core_helpers.environment == "production" ? "Welcome to osinfra.io!" : "Welcome to osinfra.io ${module.core_helpers.environment}!"

  google_oauth_enabled = var.google_oauth_client_id != "" && nonsensitive(var.google_oauth_client_secret != "")

  istio_global = data.terraform_remote_state.istio_global.outputs

  namespace = "authentik"

  openbao_hostname = local.istio_global.openbao_hostname

  # authentik matches regex entries with Python re.fullmatch, so the optional prefix accepts only the
  # zone apex and its zonal subdomains.
  redirect_uris = concat(
    [{
      matching_mode = "regex"
      url           = "https://([a-z0-9-]+\\.)*${replace(local.team_hostname, ".", "\\.")}/outpost\\.goauthentik\\.io/callback.*"
    }],
    [{
      matching_mode = "strict"
      url           = "https://${local.agentgateway_hostname}/outpost.goauthentik.io/callback"
    }],
    [
      for hostname in values(local.agentgateway_regional_hostnames) : {
        matching_mode = "strict"
        url           = "https://${hostname}/outpost.goauthentik.io/callback"
      }
    ],
  )

  superuser_group_keys = local.google_oauth_enabled ? ["${var.team}/authentik-admins"] : []

  team_hostname = local.istio_global.team_hostname
}
