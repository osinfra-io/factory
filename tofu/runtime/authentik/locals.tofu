locals {
  global = data.terraform_remote_state.global.outputs

  namespace = "authentik"

  secret_name = "authentik-env"

  stage = "authentik"

  terraform_remote_state_global_workspace = "authentik-global-${coalesce(module.core_helpers.environment, "unsupported")}"
}
