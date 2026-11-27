data "terraform_remote_state" "authentik_config" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = local.terraform_remote_state_authentik_config_workspace
}

data "terraform_remote_state" "istio_global" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = local.terraform_remote_state_istio_global_workspace
}
