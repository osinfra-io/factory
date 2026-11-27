# Required Providers
# https://opentofu.org/docs/language/providers/requirements

terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# Kubernetes authentik
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "test" {
  source = "../../../../config"

  application_groups = var.application_groups
  authentik_url      = "https://authentik.example.com"
  browser_group_policy_bindings = {
    "https://gateway.example.com" = {
      groups = ["all", "project-admins"]
      host   = "https://gateway.example.com"
    }
  }
  default_authentication_source_uuids = [
    "00000000-0000-0000-0000-000000000013",
  ]
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
  google_oauth_client_id              = var.google_oauth_client_id
  google_oauth_client_secret          = var.google_oauth_client_secret
  manage_default_authentication_stage = true
  superuser_group_keys                = var.superuser_group_keys
}
