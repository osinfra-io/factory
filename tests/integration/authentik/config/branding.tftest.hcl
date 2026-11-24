# Shared Factory authentication regression
# https://opentofu.org/docs/cli/commands/test/

mock_provider "authentik" {
  mock_resource "authentik_flow" {
    defaults = {
      uuid = "00000000-0000-0000-0000-000000000001"
    }
  }

  mock_resource "authentik_provider_oauth2" {
    defaults = {
      id = "1"
    }
  }

  mock_resource "authentik_provider_proxy" {
    defaults = {
      id = "2"
    }
  }
}

variables {
  authentik_token            = "mock-local-token"
  embedded_outpost_id        = "mock-outpost"
  import_built_in_brand      = false
  google_oauth_client_id     = "mock-google-client"
  google_oauth_client_secret = "mock-google-secret"
}

run "development_branding" {
  command = apply

  plan_options {
    target = [
      module.authentik_config.authentik_brand.this,
      module.authentik_config.authentik_flow.authentication,
      module.authentik_config.authentik_flow_stage_binding.authentication_stages,
      module.authentik_config.authentik_policy_binding.authentication_stage_policies,
    ]
  }

  assert {
    condition     = module.authentik_config.brand.domain == "authentik.localhost" && module.authentik_config.brand.branding_title == "osinfra.io | Development"
    error_message = "The Kubernetes fixture must retain the original local domain and branded title."
  }

  assert {
    condition     = module.authentik_config.brand.branding_logo == "https://docs.osinfra.io/img/osinfra-logo-full.png" && module.authentik_config.brand.branding_favicon == "https://docs.osinfra.io/img/mirko-transparent.png"
    error_message = "The local login must retain the original osinfra logo and favicon."
  }

  assert {
    condition     = jsondecode(module.authentik_config.brand.attributes).settings.theme.base == "dark" && strcontains(module.authentik_config.brand.branding_custom_css, "--pf-c-form-control--focus--after--BorderBottomColor: #606060")
    error_message = "The local login must use Factory's dark theme and focus styling."
  }

  assert {
    condition     = can(regex("body:has\\(ak-flow-executor\\)\\s*\\{[^}]*--ak-global--background-color: #1e1e1e;[^}]*--ak-global--background-image: none;", module.authentik_config.brand.branding_custom_css))
    error_message = "The branded flow page must use a solid dark background instead of the default image."
  }

  assert {
    condition     = module.authentik_config.brand.flow_authentication == module.authentik_config.flow.uuid && module.authentik_config.flow.title == "Welcome to osinfra.io development!"
    error_message = "The local brand must select the shared custom flow, not the built-in default flow."
  }

  assert {
    condition     = length(module.authentik_config.stage_bindings) == 4 && length(module.authentik_config.policy_bindings) == 2
    error_message = "Local authentication must exercise all shared stages and conditional policies."
  }
}

run "factory_access_policy" {
  command = plan

  variables {
    local_test_user_email = "local-test@example.com"
  }

  plan_options {
    target = [
      module.authentik_config.authentik_group.application,
      module.authentik_config.authentik_policy_binding.browser_access,
    ]
  }

  assert {
    condition = (
      toset(keys(module.team_access.application_groups)) == toset([
        for key in keys(var.teams["factory"].authentik_groups) : "factory/${key}"
      ]) &&
      alltrue([
        for group in values(module.team_access.application_groups) : group.members == tolist(["local-test@example.com"])
      ])
    )
    error_message = "The local test identity must be assigned to the shared Factory application groups."
  }

  assert {
    condition = (
      toset(local.superuser_group_keys) == toset(["factory/authentik-admins"]) &&
      length(setsubtract(toset(local.superuser_group_keys), toset(keys(module.team_access.application_groups)))) == 0
    )
    error_message = "Only the platform-selected authentik admins group may have instance-wide superuser access."
  }

  assert {
    condition = tomap({
      for app, binding in local.browser_group_policy_bindings : app => tolist(binding.groups)
      }) == tomap({
      agentgateway = tolist(["factory: agentgateway Admins"])
      development  = tolist(["all"])
      floor        = tolist(["all"])
      kagent       = tolist(["factory: kagent Admins"])
    })
    error_message = "The platform's shared browser applications must retain their intended group bindings."
  }
}
