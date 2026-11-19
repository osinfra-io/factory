data "terraform_remote_state" "foundation" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = var.prefix
  }
  workspace = local.foundation_workspace
}
