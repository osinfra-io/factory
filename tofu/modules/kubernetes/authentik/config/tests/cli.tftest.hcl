mock_provider "authentik" {
  mock_resource "authentik_application" {
    defaults = {
      id   = 3
      uuid = "00000000-0000-0000-0000-000000000003"
    }
  }

  mock_resource "authentik_flow" {
    defaults = {
      id   = "00000000-0000-0000-0000-000000000007"
      uuid = "00000000-0000-0000-0000-000000000007"
    }
  }

  mock_resource "authentik_group" {
    defaults = {
      id = 4
    }
  }

  mock_resource "authentik_provider_oauth2" {
    defaults = {
      client_secret = "mock-openbao-client-secret"
      id            = 1
    }
  }

  mock_resource "authentik_provider_proxy" {
    defaults = {
      id = 2
    }
  }

  mock_resource "authentik_property_mapping_provider_scope" {
    defaults = {
      id = 13
    }
  }
}

run "cli_oidc_provider" {
  command = apply

  override_resource {
    target = authentik_provider_oauth2.cli
    values = {
      id = 21
    }
  }

  override_resource {
    target = authentik_property_mapping_provider_scope.roles
    values = {
      id = 15
    }
  }

  variables {
    authentik_url                       = "https://authentik.example.com"
    cli_oidc_browser_keys               = ["floor"]
    google_oauth_client_id              = ""
    google_oauth_client_secret          = ""
    manage_default_authentication_stage = false

    browser_group_policy_bindings = {
      floor = {
        groups = ["factory"]
        host   = "https://floor.example.com"
      }
      other = {
        groups = ["factory"]
        host   = "https://other.example.com"
      }
    }

    default_authentication_stage_settings = {
      captcha_stage             = null
      case_insensitive_matching = true
      enable_remember_me        = false
      enrollment_flow           = null
      password_stage            = null
      passwordless_flow         = null
      pretend_user_exists       = true
      recovery_flow             = null
      show_matched_user         = true
      show_source_labels        = false
      user_fields               = ["email", "username"]
      webauthn_stage            = null
    }
  }

  assert {
    condition = (
      authentik_provider_oauth2.cli.client_id == "factory-cli" &&
      authentik_provider_oauth2.cli.client_type == "public" &&
      contains(authentik_provider_oauth2.cli.grant_types, "authorization_code")
    )
    error_message = "The CLI provider must be a public client using the authorization code grant."
  }

  assert {
    condition     = output.cli_issuer_url == "https://authentik.example.com/application/o/factory-cli/"
    error_message = "The CLI issuer URL must be exposed for the CLI configuration."
  }

  assert {
    condition = (
      length(authentik_provider_proxy.browser["floor"].jwt_federation_providers) == 1 &&
      length(authentik_provider_proxy.browser["other"].jwt_federation_providers) == 0
    )
    error_message = "Only the proxy providers named in cli_oidc_browser_keys may accept CLI bearer tokens."
  }
}

run "cli_oidc_disabled_by_default" {
  command = plan

  variables {
    authentik_url                       = "https://authentik.example.com"
    google_oauth_client_id              = ""
    google_oauth_client_secret          = ""
    manage_default_authentication_stage = false
  }

  assert {
    condition     = output.cli_issuer_url == null
    error_message = "The CLI provider must not exist unless a browser key opts in."
  }
}
