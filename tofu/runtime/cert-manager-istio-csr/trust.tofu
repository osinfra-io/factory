data "terraform_remote_state" "trust" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = "trust-${coalesce(module.core_helpers.environment, "unsupported")}"
}
