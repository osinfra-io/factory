data "terraform_remote_state" "global" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = "istio-global-${coalesce(module.core_helpers.environment, "unsupported")}"
}
