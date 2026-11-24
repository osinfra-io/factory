data "terraform_remote_state" "authentik_config" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = "authentik-config-${coalesce(module.core_helpers.environment, "unsupported")}"
}

data "terraform_remote_state" "istio_global" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = "istio-global-${coalesce(module.core_helpers.environment, "unsupported")}"
}
