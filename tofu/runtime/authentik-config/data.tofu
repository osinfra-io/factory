data "authentik_brand" "built_in" {
  domain = module.authentik_config.built_in_brand_domain
}

data "authentik_outpost" "embedded" {
  name = module.authentik_regional_config.embedded_outpost_name
}

data "authentik_stage" "default_authentication" {
  name = module.authentik_config.default_authentication_identification_stage_name
}

data "terraform_remote_state" "authentik_global" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = local.terraform_remote_state_authentik_global_workspace
}

data "terraform_remote_state" "istio_global" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = local.terraform_remote_state_istio_global_workspace
}
