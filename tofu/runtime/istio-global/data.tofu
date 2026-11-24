data "terraform_remote_state" "assembly" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "assembly"
  }
  workspace = "assembly-main-${coalesce(module.core_helpers.environment, "unsupported")}"
}
