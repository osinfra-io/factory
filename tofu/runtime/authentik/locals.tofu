locals {
  global = data.terraform_remote_state.global.outputs

  namespace = "authentik"

  secret_name = "authentik-env"

  stage = "authentik"
}
